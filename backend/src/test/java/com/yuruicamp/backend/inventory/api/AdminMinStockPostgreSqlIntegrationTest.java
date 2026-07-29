package com.yuruicamp.backend.inventory.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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
 * PostgreSQL 驗收：min-stock 讀寫一致、負數 400、錯 domain 400、on_hand 不變。
 * IT for ADM-W1-07 min-stock thresholds.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminMinStockPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w107-admin:w107-admin@example.test:google:W107 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w107-viewer:w107-viewer@example.test:google:W107 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

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
				VALUES ('W107-ADMIN', 'W107 Admin', 'w107-admin@example.test', 'admin', true, 'uid-w107-admin'),
				       ('W107-VIEWER', 'W107 Viewer', 'w107-viewer@example.test', 'operator', true, 'uid-w107-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99107, 'w107-cat', 'W107 分類', 99107)
				ON CONFLICT (id) DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO brands (id, name, sort_order)
				VALUES ('w107-brand', 'W107 Brand', 99107)
				ON CONFLICT (id) DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO equipment_items (id, name, category_id, brand_id, description, active)
				VALUES ('EQ-W107', 'W107 裝備', 99107, 'w107-brand', 'test', true)
				ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, active = true
				""");
		jdbc.update("""
				INSERT INTO products (id, item_id, status)
				VALUES ('P-W107', 'EQ-W107', 'active')
				ON CONFLICT (id) DO UPDATE SET status = 'active'
				""");
		jdbc.update("""
				INSERT INTO product_variants (
				    id, product_id, sku, color, size, specification, price, status)
				VALUES ('V-W107', 'P-W107', 'SKU-W107', '綠', NULL, '綠', 100.00, 'active')
				ON CONFLICT (id) DO UPDATE SET status = 'active'
				""");
		jdbc.update("""
				INSERT INTO inventory_locations (
				    id, code, inventory_domain, type, branch_id, name, active)
				VALUES ('main', 'main', 'store', 'main', NULL, '商店主倉', true),
				       ('RENTAL-C001', 'RENTAL-C001', 'rental', 'main', NULL, '租借主倉', true)
				ON CONFLICT (id) DO UPDATE SET
				    inventory_domain = EXCLUDED.inventory_domain,
				    active = true
				""");
		jdbc.update("""
				INSERT INTO inventory_stocks (
				    location_id, variant_id, on_hand_quantity, inventory_domain)
				VALUES ('main', 'V-W107', 42, 'store')
				ON CONFLICT (location_id, variant_id) DO UPDATE SET
				    on_hand_quantity = 42
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void putThenGetIsConsistentAndOnHandUnchanged() throws Exception {
		mockMvc.perform(put("/api/admin/min-stocks")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "inventoryDomain": "store",
							  "items": [
							    {"variantId":"V-W107","locationId":"main","minimumQuantity":7}
							  ]
							}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[0].minimumQuantity").value(7))
				.andExpect(jsonPath("$.data[0].productId").value("P-W107"));

		mockMvc.perform(get("/api/admin/min-stocks")
					.header("Authorization", ADMIN_TOKEN)
					.param("inventoryDomain", "store")
					.param("variantId", "V-W107")
					.param("locationId", "main"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[0].minimumQuantity").value(7));

		Integer onHand = jdbc.queryForObject(
				"SELECT on_hand_quantity FROM inventory_stocks WHERE variant_id = ? AND location_id = ?",
				Integer.class,
				"V-W107",
				"main");
		assertEquals(42, onHand);
	}

	@Test
	void rejectNegativeAndWrongDomain() throws Exception {
		mockMvc.perform(put("/api/admin/min-stocks")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "inventoryDomain": "store",
							  "items": [
							    {"variantId":"V-W107","locationId":"main","minimumQuantity":-3}
							  ]
							}
							"""))
				.andExpect(status().isBadRequest());

		mockMvc.perform(put("/api/admin/min-stocks")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "inventoryDomain": "store",
							  "items": [
							    {"variantId":"V-W107","locationId":"RENTAL-C001","minimumQuantity":2}
							  ]
							}
							"""))
				.andExpect(status().isBadRequest());
	}

	@Test
	void viewOnlyCannotPut() throws Exception {
		mockMvc.perform(put("/api/admin/min-stocks")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "inventoryDomain": "store",
							  "items": [
							    {"variantId":"V-W107","locationId":"main","minimumQuantity":1}
							  ]
							}
							"""))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM product_variant_min_stocks WHERE variant_id = 'V-W107'");
		jdbc.update("DELETE FROM inventory_stocks WHERE variant_id = 'V-W107'");
		jdbc.update("DELETE FROM product_variants WHERE id = 'V-W107'");
		jdbc.update("DELETE FROM products WHERE id = 'P-W107'");
		jdbc.update("DELETE FROM equipment_items WHERE id = 'EQ-W107'");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W107-ADMIN', 'W107-VIEWER')");
	}
}
