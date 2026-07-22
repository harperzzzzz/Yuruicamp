package com.yuruicamp.backend.inventory.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
// 使用真正 PostgreSQL 驗證 G-3 過帳鎖、冪等、負庫存與 RBAC。
class AdminInventoryMovementPostgreSqlIntegrationTest {

	private static final String TOKEN =
			"Bearer dev:uid-g3-admin:g3-admin@example.test:google:G3 Admin";

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
				VALUES ('G3-ADMIN', 'G3 Admin', 'g3-admin@example.test', 'admin', true, 'uid-g3-admin')
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99003, 'g3-test', 'G3 測試分類', 99003)
				""");
		jdbc.update("""
				INSERT INTO equipment_items (id, category_id, name, active)
				VALUES ('G3-STORE-ITEM', 99003, 'G3 商城商品', true),
				       ('G3-RENTAL-ITEM', 99003, 'G3 租借商品', true)
				""");
		jdbc.update("INSERT INTO products (id, item_id, status) VALUES ('G3-PRODUCT', 'G3-STORE-ITEM', 'active')");
		jdbc.update("""
				INSERT INTO product_variants (
				    id, product_id, sku, price, specification, status)
				VALUES ('G3-STORE-VARIANT', 'G3-PRODUCT', 'G3-STORE-SKU', 100, '標準', 'active')
				""");
		jdbc.update("INSERT INTO rental_skus (id, item_id, status) VALUES ('G3-RENTAL-SKU', 'G3-RENTAL-ITEM', 'active')");
		jdbc.update("""
				INSERT INTO rental_sku_variants (
				    id, rental_sku_id, sku, specification, status)
				VALUES ('G3-RENTAL-VARIANT', 'G3-RENTAL-SKU', 'G3-RENTAL-SKU-V1', '標準', 'active')
				""");
		jdbc.update("""
				INSERT INTO inventory_locations (id, code, inventory_domain, type, name, active)
				VALUES ('G3-STORE-SOURCE', 'G3-STORE-SOURCE', 'store', 'main', 'G3 商城來源', true),
				       ('G3-STORE-DEST', 'G3-STORE-DEST', 'store', 'inspection', 'G3 商城目的', true),
				       ('G3-RENTAL-DEST', 'G3-RENTAL-DEST', 'rental', 'main', 'G3 租借主倉', true)
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void receiptPostIsIdempotentAndPostedMovementIsImmutable() throws Exception {
		long movementId = createDraft("""
				{
				  "inventoryDomain":"store",
				  "movementType":"receipt",
				  "destinationLocationId":"G3-STORE-SOURCE",
				  "reason":"G3 測試進貨"
				}
				""");
		addItem(movementId, "G3-STORE-VARIANT", 5);

		postMovement(movementId).andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("posted"))
				.andExpect(jsonPath("$.data.employeeId").value("G3-ADMIN"));
		postMovement(movementId).andExpect(status().isOk());

		assertEquals(5, stock("G3-STORE-SOURCE", "G3-STORE-VARIANT"));
		mockMvc.perform(post("/api/admin/inventory-movements/{id}/items", movementId)
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"variantId\":\"G3-STORE-VARIANT\",\"quantity\":1}"))
				.andExpect(status().isConflict());
		mockMvc.perform(post("/api/admin/inventory-movements/{id}/cancel", movementId)
					.header("Authorization", TOKEN))
				.andExpect(status().isConflict());

		long writeOffId = createDraft("""
				{
				  "inventoryDomain":"store",
				  "movementType":"write_off",
				  "sourceLocationId":"G3-STORE-SOURCE",
				  "reason":"G3 超量損耗"
				}
				""");
		addItem(writeOffId, "G3-STORE-VARIANT", 6);
		postMovement(writeOffId).andExpect(status().isConflict());
		assertEquals(5, stock("G3-STORE-SOURCE", "G3-STORE-VARIANT"));
		mockMvc.perform(post("/api/admin/inventory-movements/{id}/cancel", writeOffId)
					.header("Authorization", TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("cancelled"));
		postMovement(writeOffId).andExpect(status().isConflict());
	}

	@Test
	void concurrentTransferPostsOnlyOnceAndRentalReceiptUsesRentalStock() throws Exception {
		jdbc.update("""
				INSERT INTO inventory_stocks (
				    location_id, variant_id, on_hand_quantity, inventory_domain)
				VALUES ('G3-STORE-SOURCE', 'G3-STORE-VARIANT', 10, 'store')
				""");
		long movementId = createDraft("""
				{
				  "inventoryDomain":"store",
				  "movementType":"transfer",
				  "sourceLocationId":"G3-STORE-SOURCE",
				  "destinationLocationId":"G3-STORE-DEST",
				  "reason":"G3 併發調撥"
				}
				""");
		addItem(movementId, "G3-STORE-VARIANT", 7);
		CountDownLatch start = new CountDownLatch(1);
		try (var executor = Executors.newFixedThreadPool(2)) {
			List<Future<Integer>> results = List.of(
					executor.submit(() -> postStatusAfter(start, movementId)),
					executor.submit(() -> postStatusAfter(start, movementId)));
			start.countDown();
			assertTrue(results.stream().allMatch(result -> futureValue(result) == 200));
		}
		assertEquals(3, stock("G3-STORE-SOURCE", "G3-STORE-VARIANT"));
		assertEquals(7, stock("G3-STORE-DEST", "G3-STORE-VARIANT"));

		long rentalMovementId = createDraft("""
				{
				  "inventoryDomain":"rental",
				  "movementType":"receipt",
				  "destinationLocationId":"G3-RENTAL-DEST",
				  "reason":"G3 租借入庫"
				}
				""");
		addItem(rentalMovementId, "G3-RENTAL-VARIANT", 4);
		postMovement(rentalMovementId).andExpect(status().isOk());
		assertEquals(
				4,
				jdbc.queryForObject("""
						SELECT on_hand_quantity
						FROM rental_sku_variant_stocks
						WHERE location_id = 'G3-RENTAL-DEST'
						  AND rental_sku_variant_id = 'G3-RENTAL-VARIANT'
						""", Integer.class));
	}

	@Test
	void viewerWithoutEditPermissionCannotCreate() throws Exception {
		jdbc.update("UPDATE admin_users SET role = 'operator' WHERE id = 'G3-ADMIN'");
		jdbc.update("""
				INSERT INTO admin_user_permissions (admin_user_id, permission_code, allowed)
				VALUES ('G3-ADMIN', 'movement.view', true),
				       ('G3-ADMIN', 'movement.edit', false)
				ON CONFLICT (admin_user_id, permission_code) DO UPDATE SET allowed = EXCLUDED.allowed
				""");

		mockMvc.perform(get("/api/admin/inventory-movements/lookups")
					.header("Authorization", TOKEN))
				.andExpect(status().isOk());
		mockMvc.perform(post("/api/admin/inventory-movements")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "inventoryDomain":"store",
							  "movementType":"receipt",
							  "destinationLocationId":"G3-STORE-SOURCE",
							  "reason":"不應建立"
							}
							"""))
				.andExpect(status().isForbidden());
	}

	private long createDraft(String body) throws Exception {
		String response = mockMvc.perform(post("/api/admin/inventory-movements")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("draft"))
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode data = objectMapper.readTree(response).path("data");

		return data.path("id").asLong();
	}

	private void addItem(long movementId, String variantId, int quantity) throws Exception {
		mockMvc.perform(post("/api/admin/inventory-movements/{id}/items", movementId)
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"variantId":"%s","quantity":%d}
							""".formatted(variantId, quantity)))
				.andExpect(status().isOk());
	}

	private org.springframework.test.web.servlet.ResultActions postMovement(long movementId) throws Exception {
		return mockMvc.perform(post("/api/admin/inventory-movements/{id}/post", movementId)
				.header("Authorization", TOKEN));
	}

	private int postStatusAfter(CountDownLatch start, long movementId) throws Exception {
		start.await();

		return postMovement(movementId)
				.andReturn()
				.getResponse()
				.getStatus();
	}

	private int futureValue(Future<Integer> future) {
		try {
			return future.get();
		}
		catch (Exception ex) {
			throw new IllegalStateException(ex);
		}
	}

	private int stock(String locationId, String variantId) {
		return jdbc.queryForObject("""
				SELECT on_hand_quantity
				FROM inventory_stocks
				WHERE location_id = ? AND variant_id = ?
				""", Integer.class, locationId, variantId);
	}

	private void cleanup() {
		jdbc.update("DELETE FROM store_inventory_movement_items WHERE movement_id IN (SELECT id FROM inventory_movements WHERE reason LIKE 'G3%')");
		jdbc.update("DELETE FROM rental_inventory_movement_items WHERE movement_id IN (SELECT id FROM inventory_movements WHERE reason LIKE 'G3%')");
		jdbc.update("DELETE FROM inventory_movements WHERE reason LIKE 'G3%'");
		jdbc.update("DELETE FROM inventory_stocks WHERE variant_id = 'G3-STORE-VARIANT'");
		jdbc.update("DELETE FROM rental_sku_variant_stocks WHERE rental_sku_variant_id = 'G3-RENTAL-VARIANT'");
		jdbc.update("DELETE FROM product_variants WHERE id = 'G3-STORE-VARIANT'");
		jdbc.update("DELETE FROM products WHERE id = 'G3-PRODUCT'");
		jdbc.update("DELETE FROM rental_sku_variants WHERE id = 'G3-RENTAL-VARIANT'");
		jdbc.update("DELETE FROM rental_skus WHERE id = 'G3-RENTAL-SKU'");
		jdbc.update("DELETE FROM equipment_items WHERE id IN ('G3-STORE-ITEM', 'G3-RENTAL-ITEM')");
		jdbc.update("DELETE FROM inventory_locations WHERE id LIKE 'G3-%'");
		jdbc.update("DELETE FROM product_categories WHERE id = 99003");
		jdbc.update("DELETE FROM admin_users WHERE id = 'G3-ADMIN'");
	}
}
