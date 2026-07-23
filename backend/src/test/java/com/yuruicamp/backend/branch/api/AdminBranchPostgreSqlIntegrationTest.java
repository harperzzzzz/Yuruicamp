package com.yuruicamp.backend.branch.api;

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
 * PostgreSQL 驗收（ADM-W2-07）：門市 CRUD、啟停、公開讀取只回 active、
 * 有訂單取貨／庫位引用時禁硬刪、RBAC。
 * <p>
 * 給新手的提醒：這份測試故意分成很多小情境（每個 @Test 一個情境），
 * 這樣任何一個規則壞掉時，看測試名稱就能馬上知道是哪個行為出問題。
 */
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
class AdminBranchPostgreSqlIntegrationTest {

	private static final String ADMIN_TOKEN =
			"Bearer dev:uid-w207-admin:w207-admin@example.test:google:W207 Admin";
	private static final String VIEW_ONLY_TOKEN =
			"Bearer dev:uid-w207-viewer:w207-viewer@example.test:google:W207 Viewer";

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
				VALUES ('W207-ADMIN', 'W207 Admin', 'w207-admin@example.test', 'admin', true, 'uid-w207-admin'),
				       ('W207-VIEWER', 'W207 Viewer', 'w207-viewer@example.test', 'operator', true, 'uid-w207-viewer')
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
	void createUpdateAndDeleteUnusedBranch() throws Exception {
		mockMvc.perform(post("/api/admin/branches")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "id": "w207-branch",
							  "name": "W207 門市",
							  "address": "測試地址 1 號",
							  "phone": "02-0000-0000",
							  "businessHours": "10:00-20:00"
							}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.id").value("w207-branch"))
				.andExpect(jsonPath("$.data.active").value(true));

		// 重複 id 建立 → 409
		mockMvc.perform(post("/api/admin/branches")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"w207-branch","name":"重複","address":"x","phone":"02","businessHours":"x"}
							"""))
				.andExpect(status().isConflict());

		mockMvc.perform(get("/api/admin/branches")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == 'w207-branch')].name", hasItem("W207 門市")));

		mockMvc.perform(patch("/api/admin/branches/{id}", "w207-branch")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"name\":\"W207 門市（改名）\"}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.name").value("W207 門市（改名）"))
				// 沒傳的欄位保留原值
				.andExpect(jsonPath("$.data.address").value("測試地址 1 號"));

		mockMvc.perform(delete("/api/admin/branches/{id}", "w207-branch")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(get("/api/admin/branches/{id}", "w207-branch")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isNotFound());
	}

	@Test
	void deactivateHidesFromPublicListButAdminStillSeesIt() throws Exception {
		createBranch("w207-toggle", "W207 停用測試門市");

		// 建立時預設 active=true → 公開 API 看得到
		mockMvc.perform(get("/api/branches"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == 'w207-toggle')]").exists());

		// PATCH active=false 就是「啟停」的停用操作，不用另開端點
		mockMvc.perform(patch("/api/admin/branches/{id}", "w207-toggle")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":false}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(false));

		// 公開 API 只回 active=true → 停用後應該看不到
		mockMvc.perform(get("/api/branches"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == 'w207-toggle')]").isEmpty());

		// 後台仍能看到（含停用），方便之後復用
		mockMvc.perform(get("/api/admin/branches/{id}", "w207-toggle")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(false));

		// 復用：PATCH active=true
		mockMvc.perform(patch("/api/admin/branches/{id}", "w207-toggle")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":true}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(true));

		mockMvc.perform(get("/api/branches"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == 'w207-toggle')]").exists());
	}

	@Test
	void deleteBlockedWhenReferencedByInventoryLocation() throws Exception {
		createBranch("w207-loc-ref", "W207 有庫位的門市");
		jdbc.update("""
				INSERT INTO inventory_locations (id, code, inventory_domain, type, branch_id, name, active)
				VALUES ('W207-LOC', 'W207-LOC', 'store', 'branch', 'w207-loc-ref', 'W207 庫位', true)
				""");

		mockMvc.perform(delete("/api/admin/branches/{id}", "w207-loc-ref")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict())
				.andExpect(jsonPath("$.error.message").value(
						org.hamcrest.Matchers.containsString("active=false")));

		// 移除庫位引用後就可以硬刪了
		jdbc.update("DELETE FROM inventory_locations WHERE id = 'W207-LOC'");
		mockMvc.perform(delete("/api/admin/branches/{id}", "w207-loc-ref")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isOk());
	}

	@Test
	void deleteBlockedWhenReferencedByOrderPickupBranch() throws Exception {
		createBranch("w207-order-ref", "W207 有訂單取貨的門市");
		jdbc.update("""
				INSERT INTO customers (id,name,email,registered_at,points,first_purchase_used,auth_provider,firebase_uid,status)
				VALUES ('W207-CUSTOMER','W207 Customer','w207-customer@example.test',now(),0,false,'google','uid-w207-customer','active')
				ON CONFLICT (id) DO UPDATE SET status='active', deleted_at=null
				""");
		jdbc.update("""
				INSERT INTO orders (id, customer_id, buyer_name_snapshot, buyer_email_snapshot, recipient_name_snapshot,
				 shipping_address_snapshot, shipping_phone_snapshot, shipping_method, pickup_branch_id,
				 subtotal, shipping_fee, discount, total, payment_method, payment_status, refund_status, status,
				 placed_at, created_at, updated_at)
				VALUES ('W207-ORDER', 'W207-CUSTOMER', 'Buyer', 'buyer@example.test', 'Recipient',
				 'Address', '0900', 'pickup', 'w207-order-ref',
				 100, 0, 0, 100, 'ecpay-credit', 'paid', 'none', 'unshipped',
				 now(), now(), now())
				""");

		mockMvc.perform(delete("/api/admin/branches/{id}", "w207-order-ref")
					.header("Authorization", ADMIN_TOKEN))
				.andExpect(status().isConflict());

		// 有引用時改用軟停用仍要可行
		mockMvc.perform(patch("/api/admin/branches/{id}", "w207-order-ref")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"active\":false}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.active").value(false));
	}

	@Test
	void viewerCannotWriteButCanRead() throws Exception {
		mockMvc.perform(get("/api/admin/branches")
					.header("Authorization", VIEW_ONLY_TOKEN))
				.andExpect(status().isOk());

		mockMvc.perform(post("/api/admin/branches")
					.header("Authorization", VIEW_ONLY_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"w207-forbidden","name":"不應建立","address":"x","phone":"02","businessHours":"x"}
							"""))
				.andExpect(status().isForbidden());
	}

	private void createBranch(String id, String name) throws Exception {
		mockMvc.perform(post("/api/admin/branches")
					.header("Authorization", ADMIN_TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{"id":"%s","name":"%s","address":"測試地址","phone":"02-0000-0000","businessHours":"10:00-20:00"}
							""".formatted(id, name)))
				.andExpect(status().isOk());
	}

	private void cleanup() {
		jdbc.update("DELETE FROM orders WHERE id = 'W207-ORDER'");
		jdbc.query("SELECT soft_delete_customer('W207-CUSTOMER')", resultSet -> {
		});
		jdbc.update("DELETE FROM inventory_locations WHERE id = 'W207-LOC'");
		jdbc.update("DELETE FROM branches WHERE id LIKE 'w207-%'");
		jdbc.update("DELETE FROM admin_users WHERE id IN ('W207-ADMIN', 'W207-VIEWER')");
	}
}
