package com.yuruicamp.backend.admin.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
// 使用真正 PostgreSQL 驗證角色權限、個人覆寫與管理員 API 授權。
class AdminRbacPostgreSqlIntegrationTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@BeforeEach
	void setUp() {
		cleanup();
		insertPermission("permissions.view", "permissions", "view");
		insertPermission("permissions.edit", "permissions", "edit");
		jdbc.update("INSERT INTO admin_role_permissions (role, permission_code) VALUES ('admin', 'permissions.view'), ('admin', 'permissions.edit') ON CONFLICT DO NOTHING");
		insertAdmin("GVIEW", "g-view@example.test", "uid-g-view", "operator");
		insertAdmin("GEDIT", "g-edit@example.test", "uid-g-edit", "admin");
		jdbc.update("INSERT INTO admin_user_permissions (admin_user_id, permission_code, allowed) VALUES ('GVIEW', 'permissions.view', true)");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void viewPermissionCanListButCannotCreate() throws Exception {
		String token = "dev:uid-g-view:g-view@example.test:google:G View";

		mockMvc.perform(get("/api/admin/users").header("Authorization", "Bearer " + token))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.success").value(true));

		mockMvc.perform(post("/api/admin/users")
					.header("Authorization", "Bearer " + token)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"name":"Blocked","email":"blocked@example.test","role":"operator"}
							"""))
				.andExpect(status().isForbidden());
	}

	@Test
	void editPermissionCanCreatePendingFirebaseBinding() throws Exception {
		String token = "dev:uid-g-edit:g-edit@example.test:google:G Edit";

		mockMvc.perform(post("/api/admin/users")
					.header("Authorization", "Bearer " + token)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"name":"New Operator","email":"new-operator@example.test","role":"operator"}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(true))
				.andExpect(jsonPath("$.data.firebaseUid").doesNotExist());
	}

	private void insertPermission(String code, String section, String action) {
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES (?, ?, ?)
				ON CONFLICT (code) DO UPDATE SET section=excluded.section, action=excluded.action
				""", code, section, action);
	}

	private void insertAdmin(String id, String email, String firebaseUid, String role) {
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES (?, 'RBAC Test', ?, ?, true, ?)
				""", id, email, role, firebaseUid);
	}

	private void cleanup() {
		jdbc.update("DELETE FROM admin_users WHERE email IN ('g-view@example.test', 'g-edit@example.test', 'new-operator@example.test', 'blocked@example.test')");
		jdbc.update("DELETE FROM admin_role_permissions WHERE permission_code IN ('permissions.view', 'permissions.edit')");
		jdbc.update("DELETE FROM admin_permissions WHERE code IN ('permissions.view', 'permissions.edit')");
	}
}
