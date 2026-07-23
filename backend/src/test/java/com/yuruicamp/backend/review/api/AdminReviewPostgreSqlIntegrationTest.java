package com.yuruicamp.backend.review.api;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

/**
 * PostgreSQL 驗收：評論列表／篩選／硬刪／photos CASCADE／RBAC（W1-06）。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminReviewPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w106-admin:w106-admin@example.test:google:W106 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w106-viewer:w106-viewer@example.test:google:W106 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES ('reviews.view', 'reviews', 'view'),
				       ('reviews.edit', 'reviews', 'edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'reviews.view'),
				       ('admin', 'reviews.edit'),
				       ('operator', 'reviews.view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('W106-ADMIN', 'W106 Admin', 'w106-admin@example.test', 'admin', true, 'uid-w106-admin'),
				       ('W106-VIEWER', 'W106 Viewer', 'w106-viewer@example.test', 'operator', true, 'uid-w106-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		// operator 預設也有 reviews.edit；此 viewer 明確關掉寫入以驗收 403
		jdbc.update("""
				INSERT INTO admin_user_permissions (admin_user_id, permission_code, allowed)
				VALUES ('W106-VIEWER', 'reviews.view', true),
				       ('W106-VIEWER', 'reviews.edit', false)
				ON CONFLICT (admin_user_id, permission_code)
				DO UPDATE SET allowed = EXCLUDED.allowed
				""");
		jdbc.update("""
				INSERT INTO customers (
				    id, name, phone, email, birthday, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid, status, avatar_url)
				VALUES ('W106-CUSTOMER', 'W106 Buyer', '0913333333', 'w106-buyer@example.test',
				        DATE '1992-03-03', now(), 0, true, 'google', 'uid-w106-buyer', 'active',
				        'https://example.test/avatar.png')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    status = 'active',
				    deleted_at = NULL,
				    avatar_url = EXCLUDED.avatar_url
				""");
		jdbc.update("""
				INSERT INTO orders (
				    id, customer_id, buyer_name_snapshot, buyer_email_snapshot,
				    recipient_name_snapshot, shipping_address_snapshot, shipping_phone_snapshot,
				    subtotal, shipping_fee, discount, total, payment_method,
				    payment_status, refund_status, status, placed_at, paid_at, created_at, updated_at)
				VALUES (
				    'W106-ORDER', 'W106-CUSTOMER', 'W106 Buyer', 'w106-buyer@example.test',
				    'W106 Buyer', '測試路 1 號', '0913333333',
				    1000.00, 0, 0, 1000.00, 'ecpay-credit',
				    'paid', 'none', 'completed', now(), now(), now(), now())
				ON CONFLICT (id) DO UPDATE SET
				    customer_id = EXCLUDED.customer_id,
				    buyer_name_snapshot = EXCLUDED.buyer_name_snapshot
				""");
		jdbc.update("DELETE FROM review_photos WHERE review_id = 'W106-REV'");
		jdbc.update("DELETE FROM reviews WHERE id = 'W106-REV'");
		jdbc.update("DELETE FROM order_items WHERE id = 9106001");
		jdbc.update("""
				INSERT INTO order_items (
				    id, order_id, product_id, variant_id, sku_snapshot, product_name_snapshot,
				    specification_snapshot, brand_name_snapshot, unit_price_snapshot, quantity)
				VALUES (
				    9106001, 'W106-ORDER', 'P001', 'V001', 'W106-SKU', 'W106 測試帳篷',
				    '標準', 'Yurui', 1000.00, 1)
				""");
		jdbc.update("""
				INSERT INTO reviews (id, order_item_id, rating, comment, created_at)
				VALUES ('W106-REV', 9106001, 2, 'W106 低分需關注', now())
				ON CONFLICT (id) DO UPDATE SET
				    order_item_id = EXCLUDED.order_item_id,
				    rating = EXCLUDED.rating,
				    comment = EXCLUDED.comment
				""");
		jdbc.update("""
				INSERT INTO review_photos (review_id, sort_order, url)
				VALUES ('W106-REV', 0, 'https://example.test/w106-photo.jpg')
				ON CONFLICT (review_id, sort_order) DO UPDATE SET url = EXCLUDED.url
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void listFiltersByProductAndRatingThenDeleteRemovesPhotos() throws Exception {
		mockMvc.perform(get("/api/admin/reviews")
					.param("productId", "P001")
					.param("rating", "2")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[*].id", hasItem("W106-REV")))
				.andExpect(jsonPath("$.data[?(@.id == 'W106-REV')].photos[0]")
						.value(hasItem("https://example.test/w106-photo.jpg")));

		mockMvc.perform(get("/api/admin/reviews/W106-REV")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.buyerName").value("W106 Buyer"))
				.andExpect(jsonPath("$.data.verifiedPurchase").value(true));

		mockMvc.perform(delete("/api/admin/reviews/W106-REV")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/reviews/W106-REV")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isNotFound());

		Integer photoCount = jdbc.queryForObject(
				"SELECT count(*) FROM review_photos WHERE review_id = 'W106-REV'",
				Integer.class);
		org.junit.jupiter.api.Assertions.assertEquals(0, photoCount);
	}

	@Test
	void viewerCannotDelete() throws Exception {
		mockMvc.perform(get("/api/admin/reviews")
					.header("Authorization", VIEW_ONLY_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(delete("/api/admin/reviews/W106-REV")
					.header("Authorization", VIEW_ONLY_TOKEN))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM review_photos WHERE review_id = 'W106-REV'");
		jdbc.update("DELETE FROM reviews WHERE id = 'W106-REV'");
		jdbc.update("DELETE FROM order_items WHERE id = 9106001");
		jdbc.update("DELETE FROM orders WHERE id = 'W106-ORDER'");
		jdbc.query("SELECT soft_delete_customer('W106-CUSTOMER')", resultSet -> {
		});
		jdbc.update("DELETE FROM admin_user_permissions WHERE admin_user_id IN ('W106-ADMIN', 'W106-VIEWER')");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W106-ADMIN', 'W106-VIEWER')");
	}
}
