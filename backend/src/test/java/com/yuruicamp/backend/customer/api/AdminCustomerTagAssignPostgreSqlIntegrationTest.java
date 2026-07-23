package com.yuruicamp.backend.customer.api;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.hasItem;
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
 * PostgreSQL 驗收：會員標籤集合取代、inactive 拒絕、列表 tagId 篩選、RBAC。
 * IT for ADM-W1-03 customer tag assign.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminCustomerTagAssignPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w103-admin:w103-admin@example.test:google:W103 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w103-viewer:w103-viewer@example.test:google:W103 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@Autowired
	private ObjectMapper objectMapper;

	private long tagA;
	private long tagB;
	private long inactiveTag;

	@BeforeEach
	void setUp() throws Exception {
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
				VALUES ('W103-ADMIN', 'W103 Admin', 'w103-admin@example.test', 'admin', true, 'uid-w103-admin'),
				       ('W103-VIEWER', 'W103 Viewer', 'w103-viewer@example.test', 'operator', true, 'uid-w103-viewer')
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
				VALUES ('W103-CUSTOMER', 'W103 Customer', '0912222222', 'w103-customer@example.test',
				        DATE '1991-02-02', now(), 0, false, 'google', 'uid-w103-customer', 'active')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    status = 'active',
				    deleted_at = NULL
				""");

		tagA = createPoolTag("W103-A", "bg-success", true);
		tagB = createPoolTag("W103-B", "bg-danger", true);
		inactiveTag = createPoolTag("W103-INACTIVE", "bg-secondary", false);
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void replaceTagsAssignsRemovesAndFiltersByTagId() throws Exception {
		mockMvc.perform(put("/api/admin/customers/W103-CUSTOMER/tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"tagIds\":[" + tagA + "," + tagB + "]}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.tags[*].id", containsInAnyOrder((int) tagA, (int) tagB)));

		mockMvc.perform(get("/api/admin/customers")
					.param("tagId", String.valueOf(tagA))
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[*].id", hasItem("W103-CUSTOMER")));

		mockMvc.perform(put("/api/admin/customers/W103-CUSTOMER/tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"tagIds\":[" + tagA + "]}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.tags.length()").value(1))
				.andExpect(jsonPath("$.data.tags[0].id").value((int) tagA));

		mockMvc.perform(get("/api/admin/customers")
					.param("tagId", String.valueOf(tagB))
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == 'W103-CUSTOMER')]").isEmpty());
	}

	@Test
	void rejectInactiveTagAndViewerWrite() throws Exception {
		mockMvc.perform(put("/api/admin/customers/W103-CUSTOMER/tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"tagIds\":[" + inactiveTag + "]}"))
				.andExpect(status().isBadRequest());

		mockMvc.perform(put("/api/admin/customers/W103-CUSTOMER/tags")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"tagIds\":[" + tagA + "]}"))
				.andExpect(status().isForbidden());
	}

	private long createPoolTag(String name, String color, boolean active) throws Exception {
		String body = objectMapper.writeValueAsString(java.util.Map.of(
				"name", name,
				"color", color,
				"sortOrder", 1,
				"active", active));
		// inactive 標籤需先建立再停用（create 預設可 active=false）
		String response = mockMvc.perform(post("/api/admin/customer-tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode root = objectMapper.readTree(response);
		return root.path("data").path("id").asLong();
	}

	private void cleanup() {
		jdbc.update("DELETE FROM customer_tag_assignments WHERE customer_id = 'W103-CUSTOMER'");
		jdbc.update("DELETE FROM customer_tags WHERE name LIKE 'W103-%'");
		jdbc.query("SELECT soft_delete_customer('W103-CUSTOMER')", resultSet -> {
		});
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W103-ADMIN', 'W103-VIEWER')");
	}
}
