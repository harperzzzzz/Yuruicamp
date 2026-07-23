package com.yuruicamp.backend.customer.api;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
 * PostgreSQL 驗收：標籤池 CRUD、重複名稱、有指派禁刪、RBAC。
 * IT for ADM-W1-02 customer tag pool.
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminCustomerTagPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w102-admin:w102-admin@example.test:google:W102 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w102-viewer:w102-viewer@example.test:google:W102 Viewer";

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
				VALUES ('W102-ADMIN', 'W102 Admin', 'w102-admin@example.test', 'admin', true, 'uid-w102-admin'),
				       ('W102-VIEWER', 'W102 Viewer', 'w102-viewer@example.test', 'operator', true, 'uid-w102-viewer')
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
				VALUES ('W102-CUSTOMER', 'W102 Customer', '0911111111', 'w102-customer@example.test',
				        DATE '1990-01-01', now(), 0, false, 'google', 'uid-w102-customer', 'active')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    status = 'active',
				    deleted_at = NULL
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void createListAndRejectDuplicateName() throws Exception {
		long tagId = createTag("W102-VIP", "bg-success", 5);

		mockMvc.perform(get("/api/admin/customer-tags")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == %s)].name".formatted(tagId))
						.value(org.hamcrest.Matchers.hasItem("W102-VIP")));

		mockMvc.perform(post("/api/admin/customer-tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"name":"W102-VIP","color":"bg-danger"}
							"""))
				.andExpect(status().isConflict());
	}

	@Test
	void deleteBlockedWhenAssignedThenDeactivateWorks() throws Exception {
		long tagId = createTag("W102-ASSIGNED", "bg-info text-dark", 1);
		jdbc.update(
				"INSERT INTO customer_tag_assignments (customer_id, tag_id) VALUES (?, ?)",
				"W102-CUSTOMER",
				tagId);

		mockMvc.perform(delete("/api/admin/customer-tags/{id}", tagId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict());

		mockMvc.perform(patch("/api/admin/customer-tags/{id}", tagId)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":false}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(false));

		mockMvc.perform(get("/api/admin/customer-tags")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == %s)]".formatted(tagId))
						.isEmpty());

		mockMvc.perform(get("/api/admin/customer-tags")
					.param("includeInactive", "true")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == %s)].active".formatted(tagId))
						.value(org.hamcrest.Matchers.hasItem(false)));
	}

	@Test
	void deleteUnusedTagAndRejectViewerWrite() throws Exception {
		long tagId = createTag("W102-DELETE-ME", "bg-secondary", 9);

		mockMvc.perform(post("/api/admin/customer-tags")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"name":"W102-NOPE","color":"bg-dark"}
							"""))
				.andExpect(status().isForbidden());

		mockMvc.perform(delete("/api/admin/customer-tags/{id}", tagId)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());
		assertEquals(0, jdbc.queryForObject(
				"SELECT count(*) FROM customer_tags WHERE id = ?", Integer.class, tagId));
	}

	private long createTag(String name, String color, int sortOrder) throws Exception {
		String body = objectMapper.writeValueAsString(java.util.Map.of(
				"name", name,
				"color", color,
				"sortOrder", sortOrder,
				"active", true));
		String response = mockMvc.perform(post("/api/admin/customer-tags")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(body))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.name").value(name))
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode root = objectMapper.readTree(response);
		return root.path("data").path("id").asLong();
	}

	private void cleanup() {
		jdbc.update("DELETE FROM customer_tag_assignments WHERE customer_id = 'W102-CUSTOMER'");
		jdbc.update("DELETE FROM customer_tags WHERE name LIKE 'W102-%'");
		jdbc.query("SELECT soft_delete_customer('W102-CUSTOMER')", resultSet -> {
		});
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W102-ADMIN', 'W102-VIEWER')");
	}
}
