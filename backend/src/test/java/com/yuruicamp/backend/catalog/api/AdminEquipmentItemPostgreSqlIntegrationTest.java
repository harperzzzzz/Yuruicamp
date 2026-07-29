package com.yuruicamp.backend.catalog.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

/**
 * PostgreSQL 驗收（W2-04 後半）：依 {@code itemId} 整組取代裝備規格／標籤，
 * 且不管這個 {@code itemId} 目前是商城商品還是租借 SKU——這支端點對兩邊共用。
 *
 * <p>{@code @Transactional} 讓每個測試方法自動 rollback，不用手動 cleanup。</p>
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Transactional
class AdminEquipmentItemPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w204b-admin:w204b-admin@example.test:google:W204b Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w204b-viewer:w204b-viewer@example.test:google:W204b Viewer";
	private static final String ITEM_ID = "EQ-W204B-IT";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbc;

	@BeforeEach
	void setUp() {
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
				VALUES ('W204B-ADMIN', 'W204b Admin', 'w204b-admin@example.test', 'admin', true, 'uid-w204b-admin'),
				       ('W204B-VIEWER', 'W204b Viewer', 'w204b-viewer@example.test', 'operator', true, 'uid-w204b-viewer')
				ON CONFLICT (id) DO UPDATE SET
				    name = EXCLUDED.name,
				    email = EXCLUDED.email,
				    role = EXCLUDED.role,
				    active = EXCLUDED.active,
				    firebase_uid = EXCLUDED.firebase_uid
				""");
		jdbc.update("""
				INSERT INTO product_categories (id, code, name, sort_order)
				VALUES (99205, 'w204b-test', 'W204b 測試分類', 99205)
				""");
		jdbc.update("""
				INSERT INTO equipment_items (id, category_id, brand_id, name, description, active)
				VALUES (?, 99205, null, 'W204b 測試裝備', '整合測試裝備', true)
				""", ITEM_ID);
	}

	@Test
	void replaceSpecsIsFullReplaceAndRejectsDuplicateKeyInRequest() throws Exception {
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/specs", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "specs": [
							    {"key":"weight","value":"4.2 kg"},
							    {"key":"material","value":"鋁合金"}
							  ]
							}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.itemId").value(ITEM_ID))
				.andExpect(jsonPath("$.data.specs.length()").value(2))
				.andExpect(jsonPath("$.data.specs[0].key").value("material"))
				.andExpect(jsonPath("$.data.specs[1].key").value("weight"));

		// 只送 weight（改值）、不送 material → material 應被刪除，不是軟停用。
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/specs", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "specs": [
							    {"key":"weight","value":"5.0 kg"}
							  ]
							}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.specs.length()").value(1))
				.andExpect(jsonPath("$.data.specs[0].key").value("weight"))
				.andExpect(jsonPath("$.data.specs[0].value").value("5.0 kg"));

		Integer materialCount = jdbc.queryForObject(
				"SELECT count(*) FROM equipment_specifications WHERE item_id = ? AND spec_key = 'material'",
				Integer.class,
				ITEM_ID);
		org.junit.jupiter.api.Assertions.assertEquals(0, materialCount);

		mockMvc.perform(get("/api/admin/equipment-items/{itemId}/specs", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.specs.length()").value(1));

		// 同一 request 內重複 key → 400，避免管理員誤以為兩筆都存到了。
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/specs", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "specs": [
							    {"key":"weight","value":"1kg"},
							    {"key":"weight","value":"2kg"}
							  ]
							}
							"""))
				.andExpect(status().isBadRequest());

		// 不存在的 itemId → 404
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/specs", "EQ-NOT-EXIST")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{ "specs": [] }
							"""))
				.andExpect(status().isNotFound());

		// 唯讀 viewer 不可寫 → 403
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/specs", ITEM_ID)
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{ "specs": [] }
							"""))
				.andExpect(status().isForbidden());
	}

	@Test
	void replaceTagsDedupesCaseInsensitivelyAndIsFullReplace() throws Exception {
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/tags", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{ "tags": ["防水", "親子適用", "防水", "PARENT-FRIENDLY"] }
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.itemId").value(ITEM_ID))
				.andExpect(jsonPath("$.data.tags.length()").value(3));

		// 換一組大小寫不同但語意重複的標籤，確認整組取代且大小寫視為同一個。
		mockMvc.perform(put("/api/admin/equipment-items/{itemId}/tags", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{ "tags": ["防水", "防水", "六人用"] }
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.tags.length()").value(2));

		Integer tagRowCount = jdbc.queryForObject(
				"SELECT count(*) FROM equipment_tags WHERE item_id = ?",
				Integer.class,
				ITEM_ID);
		org.junit.jupiter.api.Assertions.assertEquals(2, tagRowCount);

		mockMvc.perform(get("/api/admin/equipment-items/{itemId}/tags", ITEM_ID)
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.tags.length()").value(2));
	}
}
