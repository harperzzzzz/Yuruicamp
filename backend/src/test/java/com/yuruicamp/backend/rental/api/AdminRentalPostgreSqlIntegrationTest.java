package com.yuruicamp.backend.rental.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.junit.jupiter.api.parallel.Execution;
import org.junit.jupiter.api.parallel.ExecutionMode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

/**
 * PostgreSQL 驗收（W2-03）：租借 SKU 交易寫入、規格同步（缺少→inactive）、
 * 重複 SKU 衝突、上下架規則、RBAC，以及「絕對不寫庫存欄位」。
 *
 * <p>對齊 {@code AdminProductPostgreSqlIntegrationTest}／{@code AdminBrandPostgreSqlIntegrationTest}
 * 的驗收寫法，方便日後比對維護。</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminRentalPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w203-admin:w203-admin@example.test:google:W203 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w203-viewer:w203-viewer@example.test:google:W203 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private ObjectMapper objectMapper;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES ('products.view', 'products', 'view'),
				       ('products.edit', 'products', 'edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'products.view'),
				       ('admin', 'products.edit'),
				       ('operator', 'products.view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('W203-ADMIN', 'W203 Admin', 'w203-admin@example.test', 'admin', true, 'uid-w203-admin'),
				       ('W203-VIEWER', 'W203 Viewer', 'w203-viewer@example.test', 'operator', true, 'uid-w203-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99003, 'w203-test', 'W203 測試分類', 99003)
				""");
		jdbc.update("""
				INSERT INTO brands (id, name, sort_order)
				VALUES ('w203-brand', 'W203 測試品牌', 99003)
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void createSyncVariantsAndEnforceActiveRule() throws Exception {
		String createBody = """
				{
				  "name": "W203 露營椅",
				  "description": "<p>租借測試椅</p>",
				  "categoryId": 99003,
				  "brandId": "w203-brand",
				  "status": "active",
				  "variants": [
				    {"sku":"W203-RSV-001","color":"綠色","size":null,"specification":"綠色","status":"active"},
				    {"sku":"W203-RSV-002","color":"藍色","size":null,"specification":"藍色","status":"active"}
				  ]
				}
				""";
		String responseBody = mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(createBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.itemId").isNotEmpty())
				.andExpect(jsonPath("$.data.status").value("active"))
				.andExpect(jsonPath("$.data.variants.length()").value(2))
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode created = objectMapper.readTree(responseBody).path("data");
		String rentalId = created.path("id").asText();
		String itemId = created.path("itemId").asText();
		String keptVariantId = findVariantId(created, "W203-RSV-001");
		String droppedVariantId = findVariantId(created, "W203-RSV-002");

		// 重複 SKU（跟另一個 rental 的規格撞號）→ 409，不因此新增/更動任何庫存表。
		String duplicateSkuBody = """
				{
				  "name": "W203 露營椅二號",
				  "description": null,
				  "categoryId": 99003,
				  "brandId": "w203-brand",
				  "status": "active",
				  "variants": [
				    {"sku":"W203-RSV-001","specification":"重複","status":"active"}
				  ]
				}
				""";
		mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(duplicateSkuBody))
				.andExpect(status().isConflict());

		// 更新只送第一個規格：第二個規格在 DB 仍存在，但要被改成 inactive（不硬刪）。
		String updateBody = """
				{
				  "name": "W203 露營椅（更新）",
				  "description": "<p>更新後</p>",
				  "categoryId": 99003,
				  "brandId": "w203-brand",
				  "status": "active",
				  "variants": [
				    {"id":"%s","sku":"W203-RSV-001","color":"深綠色","size":null,"specification":"深綠色","status":"active"}
				  ]
				}
				""".formatted(keptVariantId);
		mockMvc.perform(put("/api/admin/rentals/{id}", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(updateBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.name").value("W203 露營椅（更新）"))
				.andExpect(jsonPath("$.data.variants.length()").value(2));

		assertEquals(
				"inactive",
				jdbc.queryForObject(
						"SELECT status FROM rental_sku_variants WHERE id = ?",
						String.class,
						droppedVariantId));
		assertEquals(
				1,
				jdbc.queryForObject(
						"SELECT count(*) FROM equipment_items WHERE id = ?",
						Integer.class,
						itemId));
		assertEquals(
				1,
				jdbc.queryForObject(
						"SELECT count(*) FROM rental_skus WHERE id = ? AND item_id = ?",
						Integer.class,
						rentalId,
						itemId));
		// 全程沒有寫過任何庫存列——本 API 完全不碰 on-hand。
		assertEquals(
				0,
				jdbc.queryForObject(
						"SELECT count(*) FROM rental_sku_variant_stocks WHERE rental_sku_variant_id IN (?, ?)",
						Integer.class,
						keptVariantId,
						droppedVariantId));

		// 下架：唯一 active 規格仍在（kept variant），下架後不可能再有 active 規格可上架回去，驗證上架規則。
		mockMvc.perform(post("/api/admin/rentals/{id}/deactivate", rentalId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("inactive"));
		mockMvc.perform(post("/api/admin/rentals/{id}/activate", rentalId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("active"));

		// 把唯一的規格也改成 inactive（SKU 本身仍可是 active，但沒有 active 規格）→ 再嘗試上架應該 409。
		String allVariantsInactiveBody = """
				{
				  "name": "W203 露營椅（更新）",
				  "description": "<p>更新後</p>",
				  "categoryId": 99003,
				  "brandId": "w203-brand",
				  "status": "inactive",
				  "variants": [
				    {"id":"%s","sku":"W203-RSV-001","color":"深綠色","size":null,"specification":"深綠色","status":"inactive"}
				  ]
				}
				""".formatted(keptVariantId);
		mockMvc.perform(put("/api/admin/rentals/{id}", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(allVariantsInactiveBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("inactive"));
		mockMvc.perform(post("/api/admin/rentals/{id}/activate", rentalId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict());
	}

	@Test
	void ignoresUnknownOnHandFieldWithoutTouchingStockAndBlocksViewerWrite() throws Exception {
		// DTO 沒有宣告 onHand 欄位，就算前端多送，Jackson 預設也只是忽略，不會 400、
		// 也絕對不會被拿去寫 rental_sku_variant_stocks（本 API 完全不碰庫存）。
		String responseBody = mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "name": "帶庫存欄位的租借椅",
							  "categoryId": 99003,
							  "brandId": "w203-brand",
							  "status": "active",
							  "onHand": 999,
							  "variants": [
							    {"sku":"W203-RSV-REJECT","specification":"標準","status":"active"}
							  ]
							}
							"""))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode created = objectMapper.readTree(responseBody).path("data");
		String variantId = findVariantId(created, "W203-RSV-REJECT");
		assertEquals(
				0,
				jdbc.queryForObject(
						"SELECT count(*) FROM rental_sku_variant_stocks WHERE rental_sku_variant_id = ?",
						Integer.class,
						variantId));

		mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "name": "無權限租借椅",
							  "categoryId": 99003,
							  "brandId": "w203-brand",
							  "status": "active",
							  "variants": [
							    {"sku":"W203-RSV-DENIED","specification":"標準","status":"active"}
							  ]
							}
							"""))
				.andExpect(status().isForbidden());
	}

	@Test
	void listFiltersByStatusAndCategory() throws Exception {
		mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "name": "W203 列表測試椅",
							  "categoryId": 99003,
							  "brandId": "w203-brand",
							  "status": "active",
							  "variants": [
							    {"sku":"W203-RSV-LIST","specification":"標準","status":"active"}
							  ]
							}
							"""))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.param("q", "W203 列表測試")
					.param("status", "active")
					.param("categoryId", "99003"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].name").value("W203 列表測試椅"));
	}

	// 回應規格依後端 ID 排序，測試以 SKU 找出要保留或停用的規格 ID。
	private String findVariantId(JsonNode rental, String sku) {
		for (JsonNode variant : rental.path("variants")) {
			if (sku.equals(variant.path("sku").asText())) {
				return variant.path("id").asText();
			}
		}

		throw new IllegalStateException("Variant not found: " + sku);
	}

	private void cleanup() {
		jdbc.update("""
				DELETE FROM rental_sku_variants
				WHERE rental_sku_id IN (
				    SELECT id FROM rental_skus
				    WHERE item_id IN (SELECT id FROM equipment_items WHERE category_id = 99003)
				)
				""");
		jdbc.update("""
				DELETE FROM rental_skus
				WHERE item_id IN (SELECT id FROM equipment_items WHERE category_id = 99003)
				""");
		jdbc.update("DELETE FROM equipment_items WHERE category_id = 99003");
		jdbc.update("DELETE FROM brands WHERE id = 'w203-brand'");
		jdbc.update("DELETE FROM product_categories WHERE id = 99003");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W203-ADMIN', 'W203-VIEWER')");
	}
}
