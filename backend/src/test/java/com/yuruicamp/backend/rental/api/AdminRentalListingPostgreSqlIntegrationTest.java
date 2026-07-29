package com.yuruicamp.backend.rental.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

/**
 * PostgreSQL 驗收（W2-04 前半）：租借上架（{@code rental_listings}）整組同步、
 * upsert 穩定 id、缺少組合改停用（不硬刪），以及公開 {@code GET /api/booking/equipment}
 * 確實反映 active listing 的變化。
 *
 * <p>用 {@code @Transactional} 讓每個測試方法結束後自動 rollback，
 * 不用手動 cleanup（寫法對齊 {@code BookingPublicIntegrationTest}）。</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Transactional
class AdminRentalListingPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w204-admin:w204-admin@example.test:google:W204 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w204-viewer:w204-viewer@example.test:google:W204 Viewer";
	private static final String CAMPGROUND_ID = "C-W204-IT";
	private static final String OTHER_CAMPGROUND_ID = "C-W204-OTHER";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private ObjectMapper objectMapper;

	@BeforeEach
	void setUp() {
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
				VALUES ('W204-ADMIN', 'W204 Admin', 'w204-admin@example.test', 'admin', true, 'uid-w204-admin'),
				       ('W204-VIEWER', 'W204 Viewer', 'w204-viewer@example.test', 'operator', true, 'uid-w204-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99204, 'w204-test', 'W204 測試分類', 99204)
				""");
		jdbc.update("""
				INSERT INTO brands (id, name, sort_order)
				VALUES ('w204-brand', 'W204 測試品牌', 99204)
				""");
		jdbc.update("""
				INSERT INTO campgrounds (id, name, region, description, active)
				VALUES (?, 'W204 測試營區', '測試區域', '整合測試自建營區', true),
				       (?, 'W204 對照營區（未設庫位）', '測試區域', '故意不建 campground_rental_locations', true)
				""", CAMPGROUND_ID, OTHER_CAMPGROUND_ID);
		jdbc.update("""
				INSERT INTO inventory_locations (id, code, inventory_domain, type, branch_id, name, active)
				VALUES ('LOC-W204-IT', 'LOC-W204-IT', 'rental', 'campground', null, 'W204 測試租借庫位', true)
				""");
		jdbc.update("""
				INSERT INTO campground_rental_locations (campground_id, location_id)
				VALUES (?, 'LOC-W204-IT')
				""", CAMPGROUND_ID);
	}

	@Test
	void syncListingsUpsertsAndSoftDeactivatesMissingAndReflectsInPublicEquipment() throws Exception {
		String rentalId = createRentalSkuWithOneVariant("W204 露營椅", "W204-RSV-001");
		String variantId = findVariantId(rentalId, "W204-RSV-001");

		// 1) PUT 建立一筆 listing → 該筆立刻反映在後台列表與公開 booking equipment。
		String createListingBody = """
				{
				  "listings": [
				    {
				      "campgroundId": "%s",
				      "rentalSkuVariantId": "%s",
				      "pricePerDayWeekday": "180.00",
				      "pricePerDayHoliday": "220.00",
				      "discount": "0.10",
				      "terrain": "草地",
				      "description": "整合測試上架",
				      "active": true
				    }
				  ]
				}
				""".formatted(CAMPGROUND_ID, variantId);
		String createResponse = mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(createListingBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].campgroundId").value(CAMPGROUND_ID))
				.andExpect(jsonPath("$.data[0].pricePerDayWeekday").value("180.00"))
				.andExpect(jsonPath("$.data[0].active").value(true))
				.andReturn()
				.getResponse()
				.getContentAsString();
		String listingId = objectMapper.readTree(createResponse).path("data").get(0).path("id").asText();

		mockMvc.perform(get("/api/booking/equipment").param("campgroundId", CAMPGROUND_ID))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].id").value(listingId))
				.andExpect(jsonPath("$.data[0].pricePerDayWeekday").value("180.00"));

		// 2) 再 PUT 一次、改價格但同一組合 → id 不變（upsert 穩定 id），公開 API 看到新價格。
		String updatePriceBody = """
				{
				  "listings": [
				    {
				      "campgroundId": "%s",
				      "rentalSkuVariantId": "%s",
				      "pricePerDayWeekday": "199.00",
				      "pricePerDayHoliday": "260.00",
				      "discount": "0",
				      "active": true
				    }
				  ]
				}
				""".formatted(CAMPGROUND_ID, variantId);
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(updatePriceBody))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].id").value(listingId))
				.andExpect(jsonPath("$.data[0].pricePerDayWeekday").value("199.00"));
		assertEquals(
				1,
				jdbc.queryForObject(
						"SELECT count(*) FROM rental_listings WHERE campground_id = ? AND rental_sku_variant_id = ?",
						Integer.class,
						CAMPGROUND_ID,
						variantId));

		mockMvc.perform(get("/api/booking/equipment").param("campgroundId", CAMPGROUND_ID))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[0].pricePerDayWeekday").value("199.00"));

		// 3) PUT 空陣列 → 這個 SKU 底下所有 listing 改成停用（不硬刪），公開 API 看不到。
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{ "listings": [] }
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].id").value(listingId))
				.andExpect(jsonPath("$.data[0].active").value(false));
		assertEquals(
				1,
				jdbc.queryForObject(
						"SELECT count(*) FROM rental_listings WHERE id = ?",
						Integer.class,
						listingId));

		mockMvc.perform(get("/api/booking/equipment").param("campgroundId", CAMPGROUND_ID))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(0));
	}

	@Test
	void rejectsInvalidReferencesAndDuplicatesAndEnforcesRbac() throws Exception {
		String rentalId = createRentalSkuWithOneVariant("W204 驗證測試椅", "W204-RSV-VALID");
		String variantId = findVariantId(rentalId, "W204-RSV-VALID");

		// 營區沒有租借庫位對照 → 404
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "listings": [
							    {"campgroundId":"%s","rentalSkuVariantId":"%s",
							     "pricePerDayWeekday":"100.00","pricePerDayHoliday":"120.00","active":true}
							  ]
							}
							""".formatted(OTHER_CAMPGROUND_ID, variantId)))
				.andExpect(status().isNotFound());

		// 規格不屬於這個租借 SKU → 404
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "listings": [
							    {"campgroundId":"%s","rentalSkuVariantId":"NOT-A-REAL-VARIANT",
							     "pricePerDayWeekday":"100.00","pricePerDayHoliday":"120.00","active":true}
							  ]
							}
							""".formatted(CAMPGROUND_ID)))
				.andExpect(status().isNotFound());

		// 同一請求內重複 (campgroundId, rentalSkuVariantId) → 400
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "listings": [
							    {"campgroundId":"%s","rentalSkuVariantId":"%s",
							     "pricePerDayWeekday":"100.00","pricePerDayHoliday":"120.00","active":true},
							    {"campgroundId":"%s","rentalSkuVariantId":"%s",
							     "pricePerDayWeekday":"111.00","pricePerDayHoliday":"130.00","active":true}
							  ]
							}
							""".formatted(CAMPGROUND_ID, variantId, CAMPGROUND_ID, variantId)))
				.andExpect(status().isBadRequest());

		// 折扣超過 0.30 上限 → 400（Bean Validation）
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "listings": [
							    {"campgroundId":"%s","rentalSkuVariantId":"%s",
							     "pricePerDayWeekday":"100.00","pricePerDayHoliday":"120.00",
							     "discount":"0.50","active":true}
							  ]
							}
							""".formatted(CAMPGROUND_ID, variantId)))
				.andExpect(status().isBadRequest());

		// 唯讀權限的 viewer 不可寫 → 403
		mockMvc.perform(put("/api/admin/rentals/{id}/listings", rentalId)
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "listings": [
							    {"campgroundId":"%s","rentalSkuVariantId":"%s",
							     "pricePerDayWeekday":"100.00","pricePerDayHoliday":"120.00","active":true}
							  ]
							}
							""".formatted(CAMPGROUND_ID, variantId)))
				.andExpect(status().isForbidden());

		// 租借 SKU 本身不存在 → 404
		mockMvc.perform(get("/api/admin/rentals/{id}/listings", "RS-NOT-EXIST")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isNotFound());
	}

	private String createRentalSkuWithOneVariant(String name, String sku) throws Exception {
		String createBody = """
				{
				  "name": "%s",
				  "categoryId": 99204,
				  "brandId": "w204-brand",
				  "status": "active",
				  "variants": [
				    {"sku":"%s","specification":"標準","status":"active"}
				  ]
				}
				""".formatted(name, sku);
		String responseBody = mockMvc.perform(post("/api/admin/rentals")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(createBody))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();

		return objectMapper.readTree(responseBody).path("data").path("id").asText();
	}

	private String findVariantId(String rentalId, String sku) throws Exception {
		String responseBody = mockMvc.perform(get("/api/admin/rentals/{id}", rentalId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode rental = objectMapper.readTree(responseBody).path("data");
		for (JsonNode variant : rental.path("variants")) {
			if (sku.equals(variant.path("sku").asText())) {
				return variant.path("id").asText();
			}
		}

		throw new IllegalStateException("Variant not found: " + sku);
	}
}
