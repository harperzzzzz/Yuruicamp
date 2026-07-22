package com.yuruicamp.backend.order.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

// 使用真正 PostgreSQL 驗證會員訂單列表、快照詳情與本人限制。
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
class MemberOrderPostgreSqlIntegrationTest {

	private static final String CUSTOMER_A = "C-ORDER-MEMBER-A";
	private static final String CUSTOMER_B = "C-ORDER-MEMBER-B";
	private static final String FIREBASE_A = "order-member-a";
	private static final String EMAIL_A = "order-member-a@example.invalid";
	private static final String ORDER_OLD = "O-MEMBER-OLD";
	private static final String ORDER_NEW = "O-MEMBER-NEW";
	private static final String ORDER_OTHER = "O-MEMBER-OTHER";
	private static final long CATEGORY_ID = 990601L;
	private static final String ITEM_ID = "I-ORDER-MEMBER-IT";
	private static final String PRODUCT_ID = "P-MEMBER-IT";
	private static final String VARIANT_ID = "V-MEMBER-IT";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@BeforeEach
	void prepareDatabase() {
		removeTestData();
		insertCustomer(CUSTOMER_A, EMAIL_A, FIREBASE_A);
		insertCustomer(CUSTOMER_B, "order-member-b@example.invalid", "order-member-b");
		insertProductReference();
		insertOrder(ORDER_OLD, CUSTOMER_A, "1000.00", Instant.now().minusSeconds(200));
		insertOrder(ORDER_NEW, CUSTOMER_A, "2400.00", Instant.now().minusSeconds(100));
		insertOrder(ORDER_OTHER, CUSTOMER_B, "900.00", Instant.now());
		insertItem(ORDER_NEW);
	}

	@AfterEach
	void cleanDatabase() {
		removeTestData();
	}

	@Test
	void listContainsOnlyOwnOrdersInNewestFirstOrder() throws Exception {
		mockMvc.perform(get("/api/me/orders")
					.header("Authorization", bearerA()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(2))
				.andExpect(jsonPath("$.data[0].id").value(ORDER_NEW))
				.andExpect(jsonPath("$.data[1].id").value(ORDER_OLD))
				.andExpect(jsonPath("$.data[0].customerId").value(CUSTOMER_A))
				.andExpect(jsonPath("$.meta.totalElements").value(2))
				.andExpect(jsonPath("$.meta.totalPages").value(1));
	}

	@Test
	void detailContainsOrderAndItemSnapshots() throws Exception {
		mockMvc.perform(get("/api/me/orders/{orderId}", ORDER_NEW)
					.header("Authorization", bearerA()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.id").value(ORDER_NEW))
				.andExpect(jsonPath("$.data.total").value("2400.00"))
				.andExpect(jsonPath("$.data.paymentMethod").value("ecpay-credit"))
				.andExpect(jsonPath("$.data.paymentStatus").value("unpaid"))
				.andExpect(jsonPath("$.data.checkoutExpiresAt").isNotEmpty())
				.andExpect(jsonPath("$.data.items.length()").value(1))
				.andExpect(jsonPath("$.data.items[0].id").isNumber())
				.andExpect(jsonPath("$.data.items[0].productName").value("會員訂單測試帳篷"))
				.andExpect(jsonPath("$.data.items[0].unitPrice").value("1200.00"))
				.andExpect(jsonPath("$.data.items[0].quantity").value(2))
				.andExpect(jsonPath("$.data.items[0].lineTotal").value("2400.00"));
	}

	@Test
	void anotherMembersOrderAndMissingOrderUseSameNotFoundResponse() throws Exception {
		mockMvc.perform(get("/api/me/orders/{orderId}", ORDER_OTHER)
					.header("Authorization", bearerA()))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

		mockMvc.perform(get("/api/me/orders/UNKNOWN")
					.header("Authorization", bearerA()))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
	}

	@Test
	void memberOrderEndpointsRequireAuthentication() throws Exception {
		mockMvc.perform(get("/api/me/orders"))
				.andExpect(status().isUnauthorized());

		mockMvc.perform(get("/api/me/orders/{orderId}", ORDER_NEW))
				.andExpect(status().isUnauthorized());
	}

	private String bearerA() {
		return "Bearer dev:" + FIREBASE_A + ":" + EMAIL_A + ":google:Tester";
	}

	private void insertOrder(String orderId, String customerId, String total, Instant placedAt) {
		jdbcTemplate.update("""
				insert into orders (
				    id, customer_id, buyer_name_snapshot, buyer_email_snapshot,
				    recipient_name_snapshot, shipping_address_snapshot,
				    shipping_phone_snapshot, subtotal, shipping_fee, discount, total,
				    payment_method, payment_status, refund_status, status,
				    placed_at, checkout_expires_at
				)
				values (?, ?, 'Order Tester', 'order@example.invalid',
				        '收件測試者', '測試市測試路 1 號', '0912345678',
				        ?::numeric, 0.00, 0.00, ?::numeric,
				        'ecpay-credit', 'unpaid', 'none', 'unshipped',
				        ?, now() + interval '15 minutes')
				""",
				orderId,
				customerId,
				total,
				total,
				java.sql.Timestamp.from(placedAt));
	}

	private void insertItem(String orderId) {
		jdbcTemplate.update("""
				insert into order_items (
				    order_id, product_id, variant_id, sku_snapshot,
				    product_name_snapshot, specification_snapshot,
				    brand_name_snapshot, image_url_snapshot,
				    unit_price_snapshot, quantity
				)
				values (?, ?, ?, 'MEMBER-IT-SKU',
				        '會員訂單測試帳篷', '雙人帳', '測試品牌',
				        '/assets/member-order-it.jpg', 1200.00, 2)
				""", orderId, PRODUCT_ID, VARIANT_ID);
	}

	private void insertProductReference() {
		jdbcTemplate.update("""
				insert into product_categories (id, code, name, sort_order)
				values (?, 'order-member-it', '會員訂單測試分類', 992)
				""", CATEGORY_ID);
		jdbcTemplate.update("""
				insert into equipment_items (id, category_id, name, description, active)
				values (?, ?, '會員訂單測試帳篷', '會員訂單整合測試', true)
				""", ITEM_ID, CATEGORY_ID);
		jdbcTemplate.update("""
				insert into products (id, item_id, status)
				values (?, ?, 'active')
				""", PRODUCT_ID, ITEM_ID);
		jdbcTemplate.update("""
				insert into product_variants (
				    id, product_id, sku, color, size, price, specification, status
				)
				values (?, ?, 'MEMBER-IT-SKU', null, null, 1200.00, '雙人帳', 'active')
				""", VARIANT_ID, PRODUCT_ID);
	}

	private void insertCustomer(String customerId, String email, String firebaseUid) {
		jdbcTemplate.update("""
				insert into customers (
				    id, name, phone, email, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid,
				    created_at, updated_at, status
				)
				values (?, 'Order Member Tester', '0912345678', ?, now(), 0,
				        false, 'google', ?, now(), now(), 'active')
				on conflict (id) do update set
				    name = excluded.name,
				    phone = excluded.phone,
				    email = excluded.email,
				    firebase_uid = excluded.firebase_uid,
				    updated_at = now()
				""", customerId, email, firebaseUid);
		jdbcTemplate.queryForObject("select reactivate_customer(?)", Boolean.class, customerId);
	}

	// 測試資料使用會員訂單專屬 ID，不依賴開發 seed。
	private void removeTestData() {
		jdbcTemplate.update(
				"delete from orders where id in (?, ?, ?)",
				ORDER_OLD,
				ORDER_NEW,
				ORDER_OTHER);
		jdbcTemplate.update("delete from product_variants where id = ?", VARIANT_ID);
		jdbcTemplate.update("delete from products where id = ?", PRODUCT_ID);
		jdbcTemplate.update("delete from equipment_items where id = ?", ITEM_ID);
		jdbcTemplate.update("delete from product_categories where id = ?", CATEGORY_ID);

		softDeleteIfPresent(CUSTOMER_A);
		softDeleteIfPresent(CUSTOMER_B);
	}

	private void softDeleteIfPresent(String customerId) {
		Integer count = jdbcTemplate.queryForObject(
				"select count(*) from customers where id = ? and status <> 'deleted'",
				Integer.class,
				customerId);
		if (count != null && count > 0) {
			jdbcTemplate.queryForObject("select soft_delete_customer(?)", Boolean.class, customerId);
		}
	}
}
