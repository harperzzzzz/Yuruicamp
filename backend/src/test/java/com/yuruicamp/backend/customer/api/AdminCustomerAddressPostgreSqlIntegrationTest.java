package com.yuruicamp.backend.customer.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.Map;

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
 * PostgreSQL 驗收：預設地址覆寫、訂單 snapshot 不變、驗證與 RBAC（W1-04）。
 * IT for ADM-W1-04 default shipping address.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminCustomerAddressPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w104-admin:w104-admin@example.test:google:W104 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w104-viewer:w104-viewer@example.test:google:W104 Viewer";
	private static final String CUSTOMER_ID = "W104-CUSTOMER";
	private static final String ORDER_ID = "W104-ORDER";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES ('customers.view', 'customers', 'view'),
				       ('customers.edit', 'customers', 'edit'),
				       ('orders.view', 'orders', 'view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'customers.view'),
				       ('admin', 'customers.edit'),
				       ('admin', 'orders.view'),
				       ('operator', 'customers.view'),
				       ('operator', 'orders.view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('W104-ADMIN', 'W104 Admin', 'w104-admin@example.test', 'admin', true, 'uid-w104-admin'),
				       ('W104-VIEWER', 'W104 Viewer', 'w104-viewer@example.test', 'operator', true, 'uid-w104-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		jdbc.update("""
				INSERT INTO customers (
				    id, name, phone, email, birthday, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid, status)
				VALUES ('W104-CUSTOMER', 'W104 Customer', '0911111111', 'w104-customer@example.test',
				        DATE '1990-01-01', now(), 0, false, 'google', 'uid-w104-customer', 'active')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    status = 'active',
				    deleted_at = NULL
				""");
		jdbc.update("""
				INSERT INTO customer_shipping_addresses (
				    customer_id, recipient_name, postal_code, city, district,
				    address_line, phone, is_default)
				VALUES ('W104-CUSTOMER', '舊收件人', '100', '臺北市', '中正區',
				        '舊地址一路 1 號', '0911111111', true)
				""");
		// 模擬已成立訂單：snapshot 固定舊地址，之後改預設地址不得動到它
		jdbc.update("""
				INSERT INTO orders (
				    id, customer_id, buyer_name_snapshot, buyer_email_snapshot,
				    recipient_name_snapshot, shipping_address_snapshot, shipping_phone_snapshot,
				    subtotal, shipping_fee, discount, total, payment_method,
				    payment_status, refund_status, status, placed_at, paid_at, created_at, updated_at)
				VALUES (
				    'W104-ORDER', 'W104-CUSTOMER', 'W104 Customer', 'w104-customer@example.test',
				    '舊收件人', '舊地址一路 1 號', '0911111111',
				    100.00, 0, 0, 100.00, 'ecpay-credit',
				    'paid', 'none', 'unshipped', now(), now(), now(), now())
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void putUpdatesDefaultAddressAndLeavesOrderSnapshotUntouched() throws Exception {
		String body = """
				{
				  "recipientName": "新收件人",
				  "postalCode": "220",
				  "city": "新北市",
				  "district": "板橋區",
				  "addressLine": "文化路二段 88 號",
				  "phone": "0987654321"
				}
				""";

		mockMvc.perform(put("/api/admin/customers/" + CUSTOMER_ID + "/default-shipping-address")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.defaultShippingAddress.recipientName").value("新收件人"))
				.andExpect(jsonPath("$.data.defaultShippingAddress.postalCode").value("220"))
				.andExpect(jsonPath("$.data.defaultShippingAddress.city").value("新北市"))
				.andExpect(jsonPath("$.data.defaultShippingAddress.district").value("板橋區"))
				.andExpect(jsonPath("$.data.defaultShippingAddress.addressLine").value("文化路二段 88 號"))
				.andExpect(jsonPath("$.data.defaultShippingAddress.phone").value("0987654321"));

		mockMvc.perform(get("/api/admin/customers/" + CUSTOMER_ID)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.defaultShippingAddress.recipientName").value("新收件人"));

		// 鐵則：訂單 snapshot 仍是舊值
		Map<String, Object> order = jdbc.queryForMap("""
				SELECT recipient_name_snapshot, shipping_address_snapshot, shipping_phone_snapshot
				FROM orders WHERE id = ?
				""", ORDER_ID);
		assertEquals("舊收件人", order.get("recipient_name_snapshot"));
		assertEquals("舊地址一路 1 號", order.get("shipping_address_snapshot"));
		assertEquals("0911111111", order.get("shipping_phone_snapshot"));

		mockMvc.perform(get("/api/admin/orders/" + ORDER_ID)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.shipping.recipientName").value("舊收件人"))
				.andExpect(jsonPath("$.data.shipping.address").value("舊地址一路 1 號"))
				.andExpect(jsonPath("$.data.shipping.phone").value("0911111111"));
	}

	@Test
	void putRejectsInvalidPhoneAndMissingFields() throws Exception {
		mockMvc.perform(put("/api/admin/customers/" + CUSTOMER_ID + "/default-shipping-address")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "recipientName": "A",
							  "postalCode": "100",
							  "city": "臺北市",
							  "district": "中正區",
							  "addressLine": "路 1 號",
							  "phone": "123"
							}
							"""))
				.andExpect(status().isBadRequest());

		mockMvc.perform(put("/api/admin/customers/" + CUSTOMER_ID + "/default-shipping-address")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "recipientName": "",
							  "postalCode": "100",
							  "city": "臺北市",
							  "district": "中正區",
							  "addressLine": "路 1 號",
							  "phone": "0912345678"
							}
							"""))
				.andExpect(status().isBadRequest());
	}

	@Test
	void putReturns404ForUnknownCustomerAnd403WithoutEdit() throws Exception {
		String body = """
				{
				  "recipientName": "A",
				  "postalCode": "100",
				  "city": "臺北市",
				  "district": "中正區",
				  "addressLine": "路 1 號",
				  "phone": "0912345678"
				}
				""";

		mockMvc.perform(put("/api/admin/customers/NO-SUCH-CUSTOMER/default-shipping-address")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isNotFound());

		mockMvc.perform(put("/api/admin/customers/" + CUSTOMER_ID + "/default-shipping-address")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM orders WHERE id = ?", ORDER_ID);
		jdbc.update("DELETE FROM customer_shipping_addresses WHERE customer_id = ?", CUSTOMER_ID);
		jdbc.query("SELECT soft_delete_customer(?)", ps -> ps.setString(1, CUSTOMER_ID), rs -> {
		});
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W104-ADMIN', 'W104-VIEWER')");
	}
}
