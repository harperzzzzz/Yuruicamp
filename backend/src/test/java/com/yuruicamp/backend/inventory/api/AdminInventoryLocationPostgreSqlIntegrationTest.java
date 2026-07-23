package com.yuruicamp.backend.inventory.api;

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
 * PostgreSQL 驗收：庫位 CRUD、有庫存禁停用、lookups 只回 active、RBAC（W2-06）。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminInventoryLocationPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w206-admin:w206-admin@example.test:google:W206 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w206-viewer:w206-viewer@example.test:google:W206 Viewer";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@BeforeEach
	void setUp() {
		cleanup();
		jdbc.update("""
				INSERT INTO admin_permissions (code, section, action)
				VALUES ('movement.view', 'movement', 'view'),
				       ('movement.edit', 'movement', 'edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'movement.view'),
				       ('admin', 'movement.edit'),
				       ('operator', 'movement.view')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('W206-ADMIN', 'W206 Admin', 'w206-admin@example.test', 'admin', true, 'uid-w206-admin'),
				       ('W206-VIEWER', 'W206 Viewer', 'w206-viewer@example.test', 'operator', true, 'uid-w206-viewer')
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
	void createStoreAndRentalLocationsThenAppearInLookups() throws Exception {
		mockMvc.perform(post("/api/admin/inventory-locations")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"W206-REPAIR","code":"w206-repair","inventoryDomain":"store",
							 "type":"repair","name":"W206 維修區","active":true}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.id").value("W206-REPAIR"));

		mockMvc.perform(post("/api/admin/inventory-locations")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"W206-RENTAL-INS","code":"w206-rental-ins","inventoryDomain":"rental",
							 "type":"inspection","name":"W206 租借檢修","active":true}
							"""))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/inventory-movements/lookups")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.locations[?(@.id == 'W206-REPAIR')].name",
						hasItem("W206 維修區")));

		mockMvc.perform(delete("/api/admin/inventory-locations/{id}", "W206-REPAIR")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());
		mockMvc.perform(delete("/api/admin/inventory-locations/{id}", "W206-RENTAL-INS")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());
	}

	@Test
	void deactivateBlockedWhenOnHandExists() throws Exception {
		// seed 主倉 main 通常有庫存
		mockMvc.perform(patch("/api/admin/inventory-locations/{id}", "main")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":false}"))
				.andExpect(status().isConflict());
	}

	@Test
	void deactivateHidesFromLookupsAndViewerCannotWrite() throws Exception {
		mockMvc.perform(post("/api/admin/inventory-locations")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"W206-TMP","code":"w206-tmp","inventoryDomain":"store",
							 "type":"damaged","name":"W206 暫存","active":true}
							"""))
				.andExpect(status().isOk());

		mockMvc.perform(patch("/api/admin/inventory-locations/{id}", "W206-TMP")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":false}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(false));

		mockMvc.perform(get("/api/admin/inventory-movements/lookups")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.locations[?(@.id == 'W206-TMP')]").isEmpty());

		mockMvc.perform(post("/api/admin/inventory-locations")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"W206-FORBIDDEN","code":"w206-f","inventoryDomain":"store",
							 "type":"repair","name":"不應建立"}
							"""))
				.andExpect(status().isForbidden());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM inventory_locations WHERE id LIKE 'W206-%'");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W206-ADMIN', 'W206-VIEWER')");
	}
}
