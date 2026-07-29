package com.yuruicamp.backend.inventory.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * ADM-W2-05：商城→租借跨領域庫存轉換 PostgreSQL 驗收。
 * 驗證成對過帳／rollback／冪等回放／併發搶最後數量，以及禁止透過 G-3 通用端點單邊操作。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
class AdminInventoryConversionPostgreSqlIntegrationTest {

	private static final String TOKEN =
			"Bearer dev:uid-cvt-admin:cvt-admin@example.test:google:CVT Admin";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private ObjectMapper objectMapper;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("INSERT INTO admin_permissions (code, section, action) VALUES ('movement.view', 'movement', 'view'), ('movement.edit', 'movement', 'edit') ON CONFLICT DO NOTHING");
		jdbc.update("INSERT INTO admin_role_permissions (role, permission_code) VALUES ('admin', 'movement.view'), ('admin', 'movement.edit') ON CONFLICT DO NOTHING");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('CVT-ADMIN', 'CVT Admin', 'cvt-admin@example.test', 'admin', true, 'uid-cvt-admin')
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99005, 'cvt-test', 'CVT 測試分類', 99005)
				""");
		jdbc.update("""
				INSERT INTO equipment_items (id, category_id, name, active)
				VALUES ('CVT-STORE-ITEM', 99005, 'CVT 商城商品', true),
				       ('CVT-RENTAL-ITEM', 99005, 'CVT 租借商品', true)
				""");
		jdbc.update("INSERT INTO products (id, item_id, status) VALUES ('CVT-PRODUCT', 'CVT-STORE-ITEM', 'active')");
		jdbc.update("""
				INSERT INTO product_variants (
				    id, product_id, sku, price, specification, status)
				VALUES ('CVT-STORE-VARIANT', 'CVT-PRODUCT', 'CVT-STORE-SKU', 100, '標準', 'active')
				""");
		jdbc.update("INSERT INTO rental_skus (id, item_id, status) VALUES ('CVT-RENTAL-SKU', 'CVT-RENTAL-ITEM', 'active')");
		jdbc.update("""
				INSERT INTO rental_sku_variants (
				    id, rental_sku_id, sku, specification, status)
				VALUES ('CVT-RENTAL-VARIANT', 'CVT-RENTAL-SKU', 'CVT-RENTAL-SKU-V1', '標準', 'active')
				""");
		jdbc.update("""
				INSERT INTO inventory_locations (id, code, inventory_domain, type, name, active)
				VALUES ('CVT-STORE-SOURCE', 'CVT-STORE-SOURCE', 'store', 'main', 'CVT 商城來源', true),
				       ('CVT-RENTAL-DEST', 'CVT-RENTAL-DEST', 'rental', 'main', 'CVT 租借主倉', true)
				""");
		jdbc.update("""
				INSERT INTO inventory_stocks (location_id, variant_id, on_hand_quantity, inventory_domain)
				VALUES ('CVT-STORE-SOURCE', 'CVT-STORE-VARIANT', 10, 'store')
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void postDeductsStoreAddsRentalAndReplaysOnRepeatedPost() throws Exception {
		long conversionId = createDraft("CVT-POST-KEY-1", 4, "CVT 成功轉換");

		postConversion(conversionId).andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("posted"))
				.andExpect(jsonPath("$.data.employeeId").value("CVT-ADMIN"));
		// 重送過帳：冪等回放，不重複扣加。
		postConversion(conversionId).andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("posted"));

		assertEquals(6, storeStock("CVT-STORE-SOURCE", "CVT-STORE-VARIANT"));
		assertEquals(4, rentalStock("CVT-RENTAL-DEST", "CVT-RENTAL-VARIANT"));

		// 兩張成對異動單本身仍是 G-3 型別的 inventory_movements 資料列，但不得被通用端點單邊操作
		// （禁止單邊假轉換）：兩邊都應該已經是 posted，透過通用端點對其中一邊 cancel 必為 409。
		long storeMovementId = jdbc.queryForObject(
				"SELECT source_movement_id FROM inventory_conversions WHERE id = ?", Long.class, conversionId);
		mockMvc.perform(post("/api/admin/inventory-movements/{id}/cancel", storeMovementId)
					.header("Authorization", TOKEN))
				.andExpect(status().isConflict());
	}

	@Test
	void insufficientStockRollsBackBothSides() throws Exception {
		long conversionId = createDraft("CVT-INSUFFICIENT-KEY", 11, "CVT 庫存不足");

		postConversion(conversionId).andExpect(status().isConflict());

		assertEquals(10, storeStock("CVT-STORE-SOURCE", "CVT-STORE-VARIANT"));
		assertEquals(0, rentalStockOrZero("CVT-RENTAL-DEST", "CVT-RENTAL-VARIANT"));
		// 兩張草稿異動單維持 draft，未被部分過帳。
		assertEquals("draft", movementStatus(conversionId, true));
		assertEquals("draft", movementStatus(conversionId, false));
	}

	@Test
	void idempotencyKeyReplaysSamePayloadAndConflictsOnDifferentPayload() throws Exception {
		String key = "CVT-IDEMPOTENT-KEY";
		long first = createDraft(key, 3, "CVT 冪等測試");
		long second = createDraft(key, 3, "CVT 冪等測試");
		assertEquals(first, second);
		assertEquals(1, jdbc.queryForObject(
				"SELECT count(*) FROM inventory_conversions WHERE idempotency_key = ?", Integer.class, key));

		mockMvc.perform(post("/api/admin/inventory-conversions")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(createBody(key, 5, "CVT 不同內容")))
				.andExpect(status().isConflict());
	}

	@Test
	void concurrentConversionsCompetingForLastUnitsOnlyOneSucceeds() throws Exception {
		long conversionA = createDraft("CVT-RACE-A", 6, "CVT 併發搶最後數量 A");
		long conversionB = createDraft("CVT-RACE-B", 6, "CVT 併發搶最後數量 B");

		CountDownLatch start = new CountDownLatch(1);
		try (var executor = Executors.newFixedThreadPool(2)) {
			List<Future<Integer>> results = List.of(
					executor.submit(() -> postStatusAfter(start, conversionA)),
					executor.submit(() -> postStatusAfter(start, conversionB)));
			start.countDown();
			long successCount = results.stream().filter(result -> futureValue(result) == 200).count();
			long conflictCount = results.stream().filter(result -> futureValue(result) == 409).count();
			assertEquals(1, successCount);
			assertEquals(1, conflictCount);
		}
		// 只有一筆成功扣減：起始 10、成功那筆 -6 = 4；失敗那筆完全沒改動庫存。
		assertEquals(4, storeStock("CVT-STORE-SOURCE", "CVT-STORE-VARIANT"));
		assertEquals(6, rentalStock("CVT-RENTAL-DEST", "CVT-RENTAL-VARIANT"));
	}

	private long createDraft(String idempotencyKey, int quantity, String reason) throws Exception {
		String response = mockMvc.perform(post("/api/admin/inventory-conversions")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(createBody(idempotencyKey, quantity, reason)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("draft"))
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode data = objectMapper.readTree(response).path("data");

		return data.path("id").asLong();
	}

	private String createBody(String idempotencyKey, int quantity, String reason) {
		return """
				{
				  "sourceLocationId":"CVT-STORE-SOURCE",
				  "destinationLocationId":"CVT-RENTAL-DEST",
				  "sourceVariantId":"CVT-STORE-VARIANT",
				  "destinationRentalVariantId":"CVT-RENTAL-VARIANT",
				  "quantity":%d,
				  "reason":"%s",
				  "idempotencyKey":"%s"
				}
				""".formatted(quantity, reason, idempotencyKey);
	}

	private ResultActions postConversion(long conversionId) throws Exception {
		return mockMvc.perform(post("/api/admin/inventory-conversions/{id}/post", conversionId)
				.header("Authorization", TOKEN));
	}

	private int postStatusAfter(CountDownLatch start, long conversionId) throws Exception {
		start.await();

		return postConversion(conversionId).andReturn().getResponse().getStatus();
	}

	private int futureValue(Future<Integer> future) {
		try {
			return future.get();
		}
		catch (Exception ex) {
			throw new IllegalStateException(ex);
		}
	}

	private String movementStatus(long conversionId, boolean source) {
		String column = source ? "source_movement_id" : "destination_movement_id";

		return jdbc.queryForObject(
				"SELECT status FROM inventory_movements WHERE id = "
						+ "(SELECT " + column + " FROM inventory_conversions WHERE id = ?)",
				String.class,
				conversionId);
	}

	private int storeStock(String locationId, String variantId) {
		return jdbc.queryForObject("""
				SELECT on_hand_quantity FROM inventory_stocks
				WHERE location_id = ? AND variant_id = ?
				""", Integer.class, locationId, variantId);
	}

	private int rentalStock(String locationId, String variantId) {
		return jdbc.queryForObject("""
				SELECT on_hand_quantity FROM rental_sku_variant_stocks
				WHERE location_id = ? AND rental_sku_variant_id = ?
				""", Integer.class, locationId, variantId);
	}

	private int rentalStockOrZero(String locationId, String variantId) {
		List<Integer> rows = jdbc.queryForList("""
				SELECT on_hand_quantity FROM rental_sku_variant_stocks
				WHERE location_id = ? AND rental_sku_variant_id = ?
				""", Integer.class, locationId, variantId);

		return rows.isEmpty() ? 0 : rows.getFirst();
	}

	private void cleanup() {
		jdbc.update("DELETE FROM inventory_conversions WHERE idempotency_key LIKE 'CVT-%'");
		jdbc.update("DELETE FROM store_inventory_movement_items WHERE movement_id IN (SELECT id FROM inventory_movements WHERE reason LIKE 'CVT%')");
		jdbc.update("DELETE FROM rental_inventory_movement_items WHERE movement_id IN (SELECT id FROM inventory_movements WHERE reason LIKE 'CVT%')");
		jdbc.update("DELETE FROM inventory_movements WHERE reason LIKE 'CVT%'");
		jdbc.update("DELETE FROM inventory_stocks WHERE variant_id = 'CVT-STORE-VARIANT'");
		jdbc.update("DELETE FROM rental_sku_variant_stocks WHERE rental_sku_variant_id = 'CVT-RENTAL-VARIANT'");
		jdbc.update("DELETE FROM product_variants WHERE id = 'CVT-STORE-VARIANT'");
		jdbc.update("DELETE FROM products WHERE id = 'CVT-PRODUCT'");
		jdbc.update("DELETE FROM rental_sku_variants WHERE id = 'CVT-RENTAL-VARIANT'");
		jdbc.update("DELETE FROM rental_skus WHERE id = 'CVT-RENTAL-SKU'");
		jdbc.update("DELETE FROM equipment_items WHERE id IN ('CVT-STORE-ITEM', 'CVT-RENTAL-ITEM')");
		jdbc.update("DELETE FROM inventory_locations WHERE id LIKE 'CVT-%'");
		jdbc.update("DELETE FROM product_categories WHERE id = 99005");
		jdbc.update("DELETE FROM admin_users WHERE id = 'CVT-ADMIN'");
	}
}
