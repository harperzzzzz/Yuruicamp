package com.yuruicamp.backend.customer.api;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.hasItem;
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
 * PostgreSQL 驗收：會員偏好集合取代、inactive 拒絕、lookup、RBAC。
 * IT for ADM-W1-05 customer preferences.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminCustomerPreferencesPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w105-admin:w105-admin@example.test:google:W105 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w105-viewer:w105-viewer@example.test:google:W105 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	private long inactiveOptionId;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES ('customers.view', 'customers', 'view'),
				       ('customers.edit', 'customers', 'edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'customers.view'),
				       ('admin', 'customers.edit'),
				       ('operator', 'customers.view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('W105-ADMIN', 'W105 Admin', 'w105-admin@example.test', 'admin', true, 'uid-w105-admin'),
				       ('W105-VIEWER', 'W105 Viewer', 'w105-viewer@example.test', 'operator', true, 'uid-w105-viewer')
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
				VALUES ('W105-CUSTOMER', 'W105 Customer', '0912333444', 'w105-customer@example.test',
				        DATE '1992-03-03', now(), 0, false, 'google', 'uid-w105-customer', 'active')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    status = 'active',
				    deleted_at = NULL
				""");

		// 確保 seed 選項存在；再塞一筆 inactive 假選項做 400 驗收
		jdbc.update("""
				INSERT INTO preference_options (id, type, code, label, sort_order, active)
				OVERRIDING SYSTEM VALUE
				VALUES
				    (1, 'style', 'glamping', 'Glamping', 1, true),
				    (2, 'style', 'backpacking', '背包旅行', 2, true),
				    (5, 'style', 'hiking', '登山健行', 5, true),
				    (9, 'equipment', 'tent', '帳篷', 1, true),
				    (11, 'equipment', 'backpack', '背包', 3, true)
				ON CONFLICT (id) DO UPDATE SET
				    type = EXCLUDED.type,
				    code = EXCLUDED.code,
				    label = EXCLUDED.label,
				    sort_order = EXCLUDED.sort_order,
				    active = true,
				    updated_at = now()
				""");
		jdbc.update("""
				INSERT INTO preference_options (type, code, label, sort_order, active)
				VALUES ('style', 'w105-inactive', 'W105 Inactive', 99, false)
				ON CONFLICT (type, code) DO UPDATE SET
				    label = EXCLUDED.label,
				    active = false,
				    updated_at = now()
				""");
		inactiveOptionId = jdbc.queryForObject(
				"SELECT id FROM preference_options WHERE code = 'w105-inactive'",
				Long.class);
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void replacePreferencesUpdatesDetailAndLookupWorks() throws Exception {
		mockMvc.perform(put("/api/admin/customers/W105-CUSTOMER/preferences")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"optionIds\":[2,5,9,11]}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.preferences.styles", containsInAnyOrder("backpacking", "hiking")))
				.andExpect(jsonPath("$.data.preferences.equipment", containsInAnyOrder("tent", "backpack")));

		mockMvc.perform(get("/api/admin/customers/W105-CUSTOMER")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.preferences.styles", hasItem("backpacking")))
				.andExpect(jsonPath("$.data.preferences.equipment", hasItem("tent")));

		// 縮減集合：只留 style=2
		mockMvc.perform(put("/api/admin/customers/W105-CUSTOMER/preferences")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"optionIds\":[2]}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.preferences.styles.length()").value(1))
				.andExpect(jsonPath("$.data.preferences.styles[0]").value("backpacking"))
				.andExpect(jsonPath("$.data.preferences.equipment.length()").value(0));

		mockMvc.perform(get("/api/admin/preference-options")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.code == 'backpacking')].id").exists())
				.andExpect(jsonPath("$.data[?(@.code == 'w105-inactive')]").isEmpty());
	}

	@Test
	void rejectInactiveOptionAndViewerWrite() throws Exception {
		mockMvc.perform(put("/api/admin/customers/W105-CUSTOMER/preferences")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"optionIds\":[" + inactiveOptionId + "]}"))
				.andExpect(status().isBadRequest());

		mockMvc.perform(put("/api/admin/customers/W105-CUSTOMER/preferences")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"optionIds\":[999999]}"))
				.andExpect(status().isBadRequest());

		mockMvc.perform(put("/api/admin/customers/W105-CUSTOMER/preferences")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"optionIds\":[2]}"))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM customer_preferences WHERE customer_id = 'W105-CUSTOMER'");
		jdbc.update("DELETE FROM preference_options WHERE code = 'w105-inactive'");
		jdbc.query("SELECT soft_delete_customer('W105-CUSTOMER')", resultSet -> {
		});
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W105-ADMIN', 'W105-VIEWER')");
	}
}
