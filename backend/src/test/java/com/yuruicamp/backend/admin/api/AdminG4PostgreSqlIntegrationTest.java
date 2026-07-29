package com.yuruicamp.backend.admin.api;

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

@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Execution(ExecutionMode.SAME_THREAD)
// 使用真正 PostgreSQL 驗證 G-4 優惠券、公休與 RBAC 寫入規則。
class AdminG4PostgreSqlIntegrationTest {

	private static final String TOKEN =
			"Bearer dev:uid-g4-admin:g4-admin@example.test:google:G4 Admin";

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
				VALUES ('discounts.view', 'discounts', 'view'),
				       ('discounts.edit', 'discounts', 'edit'),
				       ('booking-calendar.view', 'booking-calendar', 'view'),
				       ('booking-calendar.edit', 'booking-calendar', 'edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_role_permissions (role, permission_code)
				VALUES ('admin', 'discounts.view'),
				       ('admin', 'discounts.edit'),
				       ('admin', 'booking-calendar.view'),
				       ('admin', 'booking-calendar.edit')
				ON CONFLICT DO NOTHING
				""");
		jdbc.update("""
				INSERT INTO admin_users (id, name, email, role, active, firebase_uid)
				VALUES ('G4-ADMIN', 'G4 Admin', 'g4-admin@example.test', 'admin', true, 'uid-g4-admin')
				""");
		jdbc.update("""
				INSERT INTO campgrounds (id, name, region, active)
				VALUES ('G4-CAMP', 'G4 測試營區', '測試地區', true)
				""");
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void couponCrudProtectsClaimedQuantityAndDuplicateCode() throws Exception {
		long couponId = createCoupon("G4SUMMER", "G4 夏季優惠");

		mockMvc.perform(post("/api/admin/coupons")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(couponBody("G4SUMMER", "重複優惠碼")))
				.andExpect(status().isConflict());
		mockMvc.perform(patch("/api/admin/coupons/{id}", couponId)
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"status\":\"disabled\"}"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.status").value("disabled"));

		jdbc.update("UPDATE coupons SET claimed_quantity = 1 WHERE id = ?", couponId);
		mockMvc.perform(patch("/api/admin/coupons/{id}", couponId)
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("{\"issueQuantity\":0}"))
				.andExpect(status().isBadRequest());
		mockMvc.perform(delete("/api/admin/coupons/{id}", couponId)
					.header("Authorization", TOKEN))
				.andExpect(status().isConflict());

		long unusedId = createCoupon("G4DELETE", "G4 可刪除優惠");
		mockMvc.perform(delete("/api/admin/coupons/{id}", unusedId)
					.header("Authorization", TOKEN))
				.andExpect(status().isOk());
		assertEquals(0, jdbc.queryForObject(
				"SELECT count(*) FROM coupons WHERE id = ?", Integer.class, unusedId));
	}

	@Test
	void closureCrudIsVisibleToPublicBookingAndPreservesDateSemantics() throws Exception {
		long closureId = createClosure();

		mockMvc.perform(get("/api/booking/closures"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == %s)].closureType".formatted(closureId))
						.value(org.hamcrest.Matchers.hasItem("date_range")));
		mockMvc.perform(patch("/api/admin/campground-closures/{id}", closureId)
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "closureType":"weekly",
							  "weekday":2,
							  "effectiveFrom":"2026-08-01",
							  "effectiveTo":"2026-09-30",
							  "reason":"每週二維護"
							}
							"""))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.closureType").value("weekly"))
				.andExpect(jsonPath("$.data.weekday").value(2))
				.andExpect(jsonPath("$.data.startDate").doesNotExist());

		mockMvc.perform(post("/api/admin/campground-closures")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content("""
							{
							  "campgroundId":"G4-CAMP",
							  "closureType":"date_range",
							  "startDate":"2026-08-10",
							  "endDate":"2026-08-10",
							  "reason":"空區間"
							}
							"""))
				.andExpect(status().isBadRequest());
		mockMvc.perform(delete("/api/admin/campground-closures/{id}", closureId)
					.header("Authorization", TOKEN))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/booking/closures"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.id == %s)]".formatted(closureId)).isEmpty());
	}

	@Test
	void viewerCanReadButCannotWriteCouponsOrClosures() throws Exception {
		jdbc.update("UPDATE admin_users SET role = 'operator' WHERE id = 'G4-ADMIN'");
		jdbc.update("""
				INSERT INTO admin_user_permissions (admin_user_id, permission_code, allowed)
				VALUES ('G4-ADMIN', 'discounts.view', true),
				       ('G4-ADMIN', 'discounts.edit', false),
				       ('G4-ADMIN', 'booking-calendar.view', true),
				       ('G4-ADMIN', 'booking-calendar.edit', false)
				ON CONFLICT (admin_user_id, permission_code)
				DO UPDATE SET allowed = EXCLUDED.allowed
				""");

		mockMvc.perform(get("/api/admin/coupons").header("Authorization", TOKEN))
				.andExpect(status().isOk());
		mockMvc.perform(get("/api/admin/campground-closures").header("Authorization", TOKEN))
				.andExpect(status().isOk());
		mockMvc.perform(post("/api/admin/coupons")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(couponBody("G4DENIED", "不應建立")))
				.andExpect(status().isForbidden());
		mockMvc.perform(post("/api/admin/campground-closures")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(closureBody()))
				.andExpect(status().isForbidden());
	}

	private long createCoupon(String code, String name) throws Exception {
		String response = mockMvc.perform(post("/api/admin/coupons")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(couponBody(code, name)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.claimedQuantity").value(0))
				.andReturn()
				.getResponse()
				.getContentAsString();

		return objectMapper.readTree(response).path("data").path("id").asLong();
	}

	private long createClosure() throws Exception {
		String response = mockMvc.perform(post("/api/admin/campground-closures")
					.header("Authorization", TOKEN)
					.contentType(MediaType.APPLICATION_JSON)
					.content(closureBody()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.createdBy").value("G4-ADMIN"))
				.andReturn()
				.getResponse()
				.getContentAsString();
		JsonNode data = objectMapper.readTree(response).path("data");

		return data.path("id").asLong();
	}

	private String couponBody(String code, String name) {
		return """
				{
				  "code":"%s",
				  "name":"%s",
				  "discountType":"fixed",
				  "discountValue":200,
				  "minimumAmount":500,
				  "issueQuantity":10,
				  "validFrom":"2026-08-01T00:00:00Z",
				  "validUntil":"2026-09-01T00:00:00Z",
				  "status":"active",
				  "category":"promotion"
				}
				""".formatted(code, name);
	}

	private String closureBody() {
		return """
				{
				  "campgroundId":"G4-CAMP",
				  "closureType":"date_range",
				  "startDate":"2026-08-01",
				  "endDate":"2026-08-02",
				  "reason":"G4 單日維護"
				}
				""";
	}

	private void cleanup() {
		jdbc.update("DELETE FROM campground_closures WHERE campground_id = 'G4-CAMP'");
		jdbc.update("DELETE FROM coupons WHERE code LIKE 'G4%'");
		jdbc.update("DELETE FROM campgrounds WHERE id = 'G4-CAMP'");
		jdbc.update("DELETE FROM admin_users WHERE id = 'G4-ADMIN'");
	}
}
