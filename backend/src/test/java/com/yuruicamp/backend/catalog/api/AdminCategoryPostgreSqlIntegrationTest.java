package com.yuruicamp.backend.catalog.api;

import static org.hamcrest.Matchers.hasItem;
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
 * PostgreSQL 驗收：分類 CRUD、有引用禁刪、lookups 可見、RBAC（W2-01）。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminCategoryPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w201-admin:w201-admin@example.test:google:W201 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w201-viewer:w201-viewer@example.test:google:W201 Viewer";

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
				VALUES ('W201-ADMIN', 'W201 Admin', 'w201-admin@example.test', 'admin', true, 'uid-w201-admin'),
				       ('W201-VIEWER', 'W201 Viewer', 'w201-viewer@example.test', 'operator', true, 'uid-w201-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void createAppearsInLookupsAndDeleteUnused() throws Exception {
		long id = createCategory("w201-chair", "W201 露營椅", 99);

		mockMvc.perform(get("/api/admin/products/lookups")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.categories[?(@.id == %s)].name".formatted(id),
						hasItem("W201 露營椅")));

		mockMvc.perform(patch("/api/admin/categories/{id}", id)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"name\":\"W201 露營椅改名\"}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.name").value("W201 露營椅改名"));

		mockMvc.perform(delete("/api/admin/categories/{id}", id)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/categories/{id}", id)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isNotFound());
	}

	@Test
	void deleteBlockedWhenReferencedAndViewerCannotWrite() throws Exception {
		// seed 分類 1（帳篷）已被 equipment 引用
		mockMvc.perform(delete("/api/admin/categories/{id}", 1)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict());

		mockMvc.perform(post("/api/admin/categories")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"code":"w201-forbidden","name":"不應建立"}
							"""))
				.andExpect(status().isForbidden());
	}

	private long createCategory(String code, String name, int sortOrder) throws Exception {
		String body = mockMvc.perform(post("/api/admin/categories")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"code":"%s","name":"%s","sortOrder":%d}
							""".formatted(code, name, sortOrder)))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode data = objectMapper.readTree(body).path("data");
		return data.path("id").asLong();
	}

	private void cleanup() {
		jdbc.update("DELETE FROM product_categories WHERE code LIKE 'w201-%'");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W201-ADMIN', 'W201-VIEWER')");
	}
}
