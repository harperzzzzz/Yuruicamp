package com.yuruicamp.backend.booking.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

// 使用真正 PostgreSQL 與 HTTP Controller 驗收 E-1 公開讀取契約。
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Transactional
class BookingPublicIntegrationTest {

	private static final String ACTIVE_CAMPGROUND_ID = "C-BOOKING-E1-IT";
	private static final String INACTIVE_CAMPGROUND_ID = "C-BOOKING-E1-OFF";
	private static final String ACTIVE_ZONE_ID = "Z-BOOKING-E1-A";
	private static final String RENTAL_LISTING_ID = "RL-BOOKING-E1-IT";
	private static final String RENTAL_VARIANT_ID = "RSV-BOOKING-E1-IT";
	private static final long ENVIRONMENT_TAG_ID = 910_001L;
	private static final long INACTIVE_ENVIRONMENT_TAG_ID = 910_002L;
	private static final long FACILITY_TAG_ID = 910_001L;
	private static final long INACTIVE_FACILITY_TAG_ID = 910_002L;
	private static final long CLOSURE_ID = 990_001L;

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@BeforeEach
	void setUp() {
		removeTestData();

		jdbcTemplate.update("""
				insert into admin_users (id, name, email, role, active)
				values ('ADMIN-BOOKING-E1-IT', 'Booking E1 測試管理員',
				        'booking-e1-it@example.invalid', 'admin', true)
				""");
		jdbcTemplate.update("""
				insert into campgrounds (id, name, region, description, active)
				values (?, 'E1 測試營區', '測試區域', '整合測試自行建立的有效營區', true),
				       (?, 'E1 停用營區', '測試區域', '不應出現在公開 API', false)
				""", ACTIVE_CAMPGROUND_ID, INACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into campground_zones
				       (id, campground_id, type, capacity_per_site,
				        price_weekday, price_holiday, total_sites, active)
				values (?, ?, '草地區', 4, 1200.00, 1500.00, 8, true),
				       ('Z-BOOKING-E1-I', ?, '停用區', 2, 900.00, 1100.00, 2, false)
				""", ACTIVE_ZONE_ID, ACTIVE_CAMPGROUND_ID, ACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into environment_tags (id, code, label, sort_order, active)
				values (?, 'booking-e1-high-altitude', 'E1 高海拔測試', 0, true),
				       (?, 'booking-e1-hidden-environment', '停用環境標籤', 1, false)
				""", ENVIRONMENT_TAG_ID, INACTIVE_ENVIRONMENT_TAG_ID);
		jdbcTemplate.update("""
				insert into facility_tags (id, code, label, sort_order, active)
				values (?, 'booking-e1-rain-shelter', 'E1 有雨棚測試', 0, true),
				       (?, 'booking-e1-hidden-facility', '停用設施標籤', 1, false)
				""", FACILITY_TAG_ID, INACTIVE_FACILITY_TAG_ID);
		jdbcTemplate.update("""
				insert into campground_environment_tags (campground_id, tag_id)
				values (?, ?), (?, ?)
				""", ACTIVE_CAMPGROUND_ID, ENVIRONMENT_TAG_ID,
				ACTIVE_CAMPGROUND_ID, INACTIVE_ENVIRONMENT_TAG_ID);
		jdbcTemplate.update("""
				insert into campground_facility_tags (campground_id, tag_id)
				values (?, ?), (?, ?)
				""", ACTIVE_CAMPGROUND_ID, FACILITY_TAG_ID,
				ACTIVE_CAMPGROUND_ID, INACTIVE_FACILITY_TAG_ID);

		jdbcTemplate.update("""
				insert into booking_policies
				       (id, booking_window_days, advance_days, max_nights,
				        timezone, date_boundary_hour, low_availability_threshold)
				values (1, 90, 1, 7, 'Asia/Taipei', 0, 20)
				on conflict (id) do update set
				    booking_window_days = excluded.booking_window_days,
				    advance_days = excluded.advance_days,
				    max_nights = excluded.max_nights,
				    timezone = excluded.timezone,
				    date_boundary_hour = excluded.date_boundary_hour,
				    low_availability_threshold = excluded.low_availability_threshold
				""");
		jdbcTemplate.update("delete from booking_policy_occupying_statuses where policy_id = 1");
		jdbcTemplate.update("""
				insert into booking_policy_occupying_statuses (policy_id, status)
				values (1, 'pending'::booking_status), (1, 'confirmed'::booking_status)
				""");

		jdbcTemplate.update("""
				insert into product_categories (id, code, name, sort_order)
				values (910001, 'booking-e1-it', 'Booking E1 測試分類', 999)
				""");
		jdbcTemplate.update("""
				insert into brands (id, name, sort_order)
				values ('BRAND-BOOKING-E1-IT', 'Booking E1 測試品牌', 999)
				""");
		jdbcTemplate.update("""
				insert into equipment_items
				       (id, category_id, brand_id, name, description, active)
				values ('E-BOOKING-E1-IT', 910001, 'BRAND-BOOKING-E1-IT',
				        'E1 測試租借裝備', '整合測試裝備', true)
				""");
		jdbcTemplate.update("""
				insert into rental_skus (id, item_id, status)
				values ('RS-BOOKING-E1-IT', 'E-BOOKING-E1-IT', 'active')
				""");
		jdbcTemplate.update("""
				insert into rental_sku_variants
				       (id, rental_sku_id, sku, color, size, specification, status)
				values (?, 'RS-BOOKING-E1-IT', 'BOOKING-E1-IT-SKU',
				        '測試色', null, '整合測試規格', 'active')
				""", RENTAL_VARIANT_ID);
		jdbcTemplate.update("""
				insert into inventory_locations
				       (id, code, inventory_domain, type, branch_id, name, active)
				values ('LOC-BOOKING-E1-IT', 'BOOKING-E1-IT', 'rental',
				        'campground', null, 'E1 測試租借庫位', true)
				""");
		jdbcTemplate.update("""
				insert into campground_rental_locations (campground_id, location_id)
				values (?, 'LOC-BOOKING-E1-IT')
				""", ACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into rental_listings
				       (id, campground_id, rental_sku_variant_id,
				        price_per_day_weekday, price_per_day_holiday, discount, active)
				values (?, ?, ?, 180.00, 220.00, 0, true)
				""", RENTAL_LISTING_ID, ACTIVE_CAMPGROUND_ID, RENTAL_VARIANT_ID);
		jdbcTemplate.update("""
				insert into rental_sku_variant_stocks
				       (location_id, rental_sku_variant_id, on_hand_quantity)
				values ('LOC-BOOKING-E1-IT', ?, 6)
				""", RENTAL_VARIANT_ID);
		jdbcTemplate.update("""
				insert into campground_closures
				       (id, campground_id, closure_type, start_date, end_date,
				        weekday, effective_from, effective_to, reason, created_by)
				values (?, ?, 'date_range', date '2026-09-01', date '2026-09-02',
				        null, null, null, 'E1 整合測試關閉日', 'ADMIN-BOOKING-E1-IT')
				""", CLOSURE_ID, ACTIVE_CAMPGROUND_ID);
	}

	@AfterEach
	void tearDown() {
		removeTestData();
	}

	@Test
	void campgroundListIsPublicAndFiltersInactiveRows() throws Exception {
		mockMvc.perform(get("/api/booking/campgrounds"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.success").value(true))
				.andExpect(jsonPath("$.data[?(@.id == 'C-BOOKING-E1-IT')]").exists())
				.andExpect(jsonPath("$.data[?(@.id == 'C-BOOKING-E1-OFF')]").doesNotExist())
				.andExpect(jsonPath("$.data[?(@.id == 'C-BOOKING-E1-IT')].environmentTags[0]")
						.value("E1 高海拔測試"))
				.andExpect(jsonPath("$.data[?(@.id == 'C-BOOKING-E1-IT')].facilityTags[0]")
						.value("E1 有雨棚測試"))
				.andExpect(jsonPath("$.meta.totalElements").isNumber());
	}

	@Test
	void campgroundDetailContainsOnlyActiveZonesAndMoneyStrings() throws Exception {
		mockMvc.perform(get("/api/booking/campgrounds/{id}", ACTIVE_CAMPGROUND_ID))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.id").value(ACTIVE_CAMPGROUND_ID))
				.andExpect(jsonPath("$.data.environmentTags.length()").value(1))
				.andExpect(jsonPath("$.data.environmentTags[0]").value("E1 高海拔測試"))
				.andExpect(jsonPath("$.data.facilityTags.length()").value(1))
				.andExpect(jsonPath("$.data.facilityTags[0]").value("E1 有雨棚測試"))
				.andExpect(jsonPath("$.data.zones.length()").value(1))
				.andExpect(jsonPath("$.data.zones[0].id").value(ACTIVE_ZONE_ID))
				.andExpect(jsonPath("$.data.zones[0].priceWeekday").value("1200.00"))
				.andExpect(jsonPath("$.data.zones[0].priceHoliday").value("1500.00"));
	}

	@Test
	void unknownOrInactiveCampgroundReturnsNotFound() throws Exception {
		mockMvc.perform(get("/api/booking/campgrounds/{id}", INACTIVE_CAMPGROUND_ID))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

		mockMvc.perform(get("/api/booking/campgrounds/UNKNOWN"))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
	}

	@Test
	void equipmentUsesActiveRentalReadModelWithoutMockStockField() throws Exception {
		mockMvc.perform(get("/api/booking/equipment").param("campgroundId", ACTIVE_CAMPGROUND_ID))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].id").value(RENTAL_LISTING_ID))
				.andExpect(jsonPath("$.data[0].rentalSkuVariantId").value(RENTAL_VARIANT_ID))
				.andExpect(jsonPath("$.data[0].pricePerDayWeekday").value("180.00"))
				.andExpect(jsonPath("$.data[0].pricePerDayHoliday").value("220.00"))
				.andExpect(jsonPath("$.data[0].stock").doesNotExist());
	}

	@Test
	void equipmentRequiresCampgroundId() throws Exception {
		mockMvc.perform(get("/api/booking/equipment"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
	}

	@Test
	void policyContainsOnlyPendingAndConfirmedOccupyingStatuses() throws Exception {
		mockMvc.perform(get("/api/booking/policy"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.bookingWindowDays").value(90))
				.andExpect(jsonPath("$.data.timezone").value("Asia/Taipei"))
				.andExpect(jsonPath("$.data.occupyingStatuses.length()").value(2))
				.andExpect(jsonPath("$.data.occupyingStatuses[0]").value("confirmed"))
				.andExpect(jsonPath("$.data.occupyingStatuses[1]").value("pending"));
	}

	@Test
	void closuresReturnDevelopmentDateRangeFixture() throws Exception {
		mockMvc.perform(get("/api/booking/closures"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data[?(@.campgroundId == 'C-BOOKING-E1-IT')].closureType")
						.value("date_range"))
				.andExpect(jsonPath("$.data[?(@.campgroundId == 'C-BOOKING-E1-IT')].startDate")
						.value("2026-09-01"))
				.andExpect(jsonPath("$.data[?(@.campgroundId == 'C-BOOKING-E1-IT')].endDate")
						.value("2026-09-02"));
	}

	// 每個測試使用獨立可辨識資料，並依外鍵反向清除，避免依賴開發 Seed。
	private void removeTestData() {
		jdbcTemplate.update("delete from campground_closures where id = ?", CLOSURE_ID);
		jdbcTemplate.update("delete from campground_environment_tags where campground_id = ?", ACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("delete from campground_facility_tags where campground_id = ?", ACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("delete from rental_sku_variant_stocks where rental_sku_variant_id = ?", RENTAL_VARIANT_ID);
		jdbcTemplate.update("delete from rental_listings where id = ?", RENTAL_LISTING_ID);
		jdbcTemplate.update("delete from campground_rental_locations where campground_id = ?", ACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("delete from inventory_locations where id = 'LOC-BOOKING-E1-IT'");
		jdbcTemplate.update("delete from rental_sku_variants where id = ?", RENTAL_VARIANT_ID);
		jdbcTemplate.update("delete from rental_skus where id = 'RS-BOOKING-E1-IT'");
		jdbcTemplate.update("delete from equipment_items where id = 'E-BOOKING-E1-IT'");
		jdbcTemplate.update("delete from product_categories where id = 910001");
		jdbcTemplate.update("delete from brands where id = 'BRAND-BOOKING-E1-IT'");
		jdbcTemplate.update("delete from campground_zones where campground_id in (?, ?)",
				ACTIVE_CAMPGROUND_ID, INACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("delete from campgrounds where id in (?, ?)",
				ACTIVE_CAMPGROUND_ID, INACTIVE_CAMPGROUND_ID);
		jdbcTemplate.update("delete from environment_tags where id in (?, ?)",
				ENVIRONMENT_TAG_ID, INACTIVE_ENVIRONMENT_TAG_ID);
		jdbcTemplate.update("delete from facility_tags where id in (?, ?)",
				FACILITY_TAG_ID, INACTIVE_FACILITY_TAG_ID);
		jdbcTemplate.update("delete from admin_users where id = 'ADMIN-BOOKING-E1-IT'");
	}
}
