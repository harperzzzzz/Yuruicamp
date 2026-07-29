package com.yuruicamp.backend.catalog.api;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
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
 * PostgreSQL 驗收：品牌 CRUD、有引用禁刪、lookups 可見、RBAC（W2-02）。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminBrandPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w202-admin:w202-admin@example.test:google:W202 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w202-viewer:w202-viewer@example.test:google:W202 Viewer";

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
				VALUES ('W202-ADMIN', 'W202 Admin', 'w202-admin@example.test', 'admin', true, 'uid-w202-admin'),
				       ('W202-VIEWER', 'W202 Viewer', 'w202-viewer@example.test', 'operator', true, 'uid-w202-viewer')
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
		mockMvc.perform(post("/api/admin/brands")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"w202-brand","name":"W202 Brand","sortOrder":88}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.id").value("w202-brand"));

		mockMvc.perform(get("/api/admin/products/lookups")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.brands[?(@.id == 'w202-brand')].name",
						hasItem("W202 Brand")));

		mockMvc.perform(patch("/api/admin/brands/{id}", "w202-brand")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"name\":\"W202 Brand Renamed\"}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.name").value("W202 Brand Renamed"));

		mockMvc.perform(delete("/api/admin/brands/{id}", "w202-brand")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/brands/{id}", "w202-brand")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isNotFound());
	}

	@Test
	void deleteBlockedWhenReferencedAndViewerCannotWrite() throws Exception {
		mockMvc.perform(delete("/api/admin/brands/{id}", "coleman")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict());

		mockMvc.perform(post("/api/admin/brands")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"w202-forbidden","name":"不應建立"}
							"""))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM brands WHERE id LIKE 'w202-%'");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W202-ADMIN', 'W202-VIEWER')");
	}
}
