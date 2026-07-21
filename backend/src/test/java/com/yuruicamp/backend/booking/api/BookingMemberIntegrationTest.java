package com.yuruicamp.backend.booking.api;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.LocalDate;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

// 使用真正 PostgreSQL 驗證 E-5 分頁、本人限制與快照詳情。
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
class BookingMemberIntegrationTest {

	private static final String CUSTOMER_A = "C-BOOKING-E5-A";
	private static final String CUSTOMER_B = "C-BOOKING-E5-B";
	private static final String FIREBASE_A = "booking-e5-a";
	private static final String EMAIL_A = "booking-e5-a@example.invalid";
	private static final String CAMPGROUND_ID = "C-BOOKING-E5-IT";
	private static final String ZONE_ID = "Z-BOOKING-E5-IT";
	private static final long CATEGORY_ID = 990501L;
	private static final String ITEM_ID = "I-BOOKING-E5";
	private static final String RENTAL_SKU_ID = "RS-BOOKING-E5";
	private static final String VARIANT_ID = "RSV-BOOKING-E5";
	private static final String LISTING_ID = "RL-BOOKING-E5";
	private static final String LOCATION_ID = "L-BOOKING-E5";
	private static final String BOOKING_OLD = "B-BOOKING-E5-OLD";
	private static final String BOOKING_DETAIL = "B-BOOKING-E5-DETAIL";
	private static final String BOOKING_NEW = "B-BOOKING-E5-NEW";
	private static final String BOOKING_OTHER = "B-BOOKING-E5-OTHER";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	@BeforeEach
	void prepareDatabase() {
		removeTestData();
		insertCustomer(CUSTOMER_A, EMAIL_A, FIREBASE_A);
		insertCustomer(CUSTOMER_B, "booking-e5-b@example.invalid", "booking-e5-b");
		insertReferenceData();
		insertBookings();
	}

	@AfterEach
	void cleanDatabase() {
		removeTestData();
	}

	@Test
	void memberListIsPagedAndContainsOnlyOwnBookings() throws Exception {
		mockMvc.perform(get("/api/booking/bookings")
					.header("Authorization", bearerA())
					.param("page", "0")
					.param("size", "2"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(2))
				.andExpect(jsonPath("$.data[0].bookingId").value(BOOKING_NEW))
				.andExpect(jsonPath("$.data[1].bookingId").value(BOOKING_DETAIL))
				.andExpect(jsonPath("$.data[0].finalAmount").value("3000.00"))
				.andExpect(jsonPath("$.meta.page").value(0))
				.andExpect(jsonPath("$.meta.size").value(2))
				.andExpect(jsonPath("$.meta.totalElements").value(3))
				.andExpect(jsonPath("$.meta.totalPages").value(2));

		mockMvc.perform(get("/api/booking/bookings")
					.header("Authorization", bearerA())
					.param("page", "1")
					.param("size", "2"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.length()").value(1))
				.andExpect(jsonPath("$.data[0].bookingId").value(BOOKING_OLD));
	}

	@Test
	void detailContainsStatusMoneyZonesAndRentals() throws Exception {
		mockMvc.perform(get("/api/booking/bookings/{id}", BOOKING_DETAIL)
					.header("Authorization", bearerA()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.bookingId").value(BOOKING_DETAIL))
				.andExpect(jsonPath("$.data.status").value("pending"))
				.andExpect(jsonPath("$.data.paymentStatus").value("unpaid"))
				.andExpect(jsonPath("$.data.campgroundName").value("E5 測試營區"))
				.andExpect(jsonPath("$.data.guestCount").value(4))
				.andExpect(jsonPath("$.data.pricing.zoneTotal").value("2500.00"))
				.andExpect(jsonPath("$.data.pricing.rentalTotal").value("450.00"))
				.andExpect(jsonPath("$.data.pricing.finalAmount").value("2950.00"))
				.andExpect(jsonPath("$.data.zones[0].zoneId").value(ZONE_ID))
				.andExpect(jsonPath("$.data.zones[0].lineTotal").value("2500.00"))
				.andExpect(jsonPath("$.data.rentals[0].rentalListingId").value(LISTING_ID))
				.andExpect(jsonPath("$.data.rentals[0].lineTotal").value("450.00"));
	}

	@Test
	void checkoutSessionUsesSameOwnedSnapshot() throws Exception {
		mockMvc.perform(get("/api/booking/checkout/sessions/{id}", BOOKING_DETAIL)
					.header("Authorization", bearerA()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.bookingId").value(BOOKING_DETAIL))
				.andExpect(jsonPath("$.data.checkoutStep").value("ready_to_pay"))
				.andExpect(jsonPath("$.data.zones.length()").value(1))
				.andExpect(jsonPath("$.data.rentals.length()").value(1));
	}

	@Test
	void anotherMembersBookingReturnsNotFoundForBothEndpoints() throws Exception {
		mockMvc.perform(get("/api/booking/bookings/{id}", BOOKING_OTHER)
					.header("Authorization", bearerA()))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));

		mockMvc.perform(get("/api/booking/checkout/sessions/{id}", BOOKING_OTHER)
					.header("Authorization", bearerA()))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
	}

	@Test
	void missingBookingReturnsSameNotFoundShape() throws Exception {
		mockMvc.perform(get("/api/booking/bookings/UNKNOWN")
					.header("Authorization", bearerA()))
				.andExpect(status().isNotFound())
				.andExpect(jsonPath("$.error.code").value("NOT_FOUND"));
	}

	@Test
	void memberReadEndpointsRequireAuthentication() throws Exception {
		mockMvc.perform(get("/api/booking/bookings"))
				.andExpect(status().isUnauthorized());

		mockMvc.perform(get("/api/booking/checkout/sessions/{id}", BOOKING_DETAIL))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void invalidPaginationReturnsValidationError() throws Exception {
		mockMvc.perform(get("/api/booking/bookings")
					.header("Authorization", bearerA())
					.param("page", "-1")
					.param("size", "101"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("VALIDATION_ERROR"));
	}

	private String bearerA() {
		return "Bearer dev:" + FIREBASE_A + ":" + EMAIL_A + ":google:Tester";
	}

	private void insertBookings() {
		LocalDate checkIn = LocalDate.now().plusDays(10);
		insertBooking(BOOKING_OLD, CUSTOMER_A, checkIn, "3000.00", Instant.now().minusSeconds(300));
		insertBooking(BOOKING_DETAIL, CUSTOMER_A, checkIn, "2950.00", Instant.now().minusSeconds(200));
		insertBooking(BOOKING_NEW, CUSTOMER_A, checkIn, "3000.00", Instant.now().minusSeconds(100));
		insertBooking(BOOKING_OTHER, CUSTOMER_B, checkIn, "3000.00", Instant.now());

		jdbcTemplate.update("""
				insert into booking_selected_zones (
				    booking_id, zone_id, zone_type_snapshot,
				    price_weekday_snapshot, price_holiday_snapshot, quantity
				)
				values (?, ?, '草地區', 1000.00, 1500.00, 1)
				""", BOOKING_DETAIL, ZONE_ID);
		jdbcTemplate.update("""
				insert into booking_selected_rentals (
				    booking_id, rental_listing_id, rental_sku_variant_id,
				    sku_snapshot, name_snapshot, specification_snapshot,
				    price_weekday_snapshot, price_holiday_snapshot,
				    discount_snapshot, quantity
				)
				values (?, ?, ?, 'RENTAL-E5', 'E5 測試桌椅', '雙人組',
				        200.00, 300.00, 0.10, 1)
				""", BOOKING_DETAIL, LISTING_ID, VARIANT_ID);
	}

	private void insertBooking(
			String bookingId,
			String customerId,
			LocalDate checkIn,
			String finalAmount,
			Instant createdAt) {
		String zoneTotal = BOOKING_DETAIL.equals(bookingId) ? "2500.00" : "3000.00";
		String rentalTotal = BOOKING_DETAIL.equals(bookingId) ? "450.00" : "0.00";

		jdbcTemplate.update("""
				insert into bookings (
				    id, customer_id, campground_id, campground_name_snapshot,
				    region_snapshot, check_in, check_out, guest_count,
				    weekday_count, holiday_count, zone_total, rental_total,
				    applied_discount, final_amount, payment_method, payment_status,
				    checkout_expires_at, status, created_at, updated_at
				)
				values (?, ?, ?, 'E5 測試營區', '測試區域', ?, ?, 4,
				        1, 1, ?::numeric, ?::numeric, 0.00, ?::numeric,
				        'ecpay-credit', 'unpaid', now() + interval '15 minutes',
				        'pending', ?, ?)
				""",
				bookingId,
				customerId,
				CAMPGROUND_ID,
				checkIn,
				checkIn.plusDays(2),
				zoneTotal,
				rentalTotal,
				finalAmount,
				java.sql.Timestamp.from(createdAt),
				java.sql.Timestamp.from(createdAt));
	}

	private void insertReferenceData() {
		jdbcTemplate.update("""
				insert into campgrounds (id, name, region, description, active)
				values (?, 'E5 測試營區', '測試區域', '會員查詢整合測試', true)
				""", CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into campground_zones (
				    id, campground_id, type, capacity_per_site,
				    price_weekday, price_holiday, total_sites, active
				)
				values (?, ?, '草地區', 4, 1000.00, 1500.00, 5, true)
				""", ZONE_ID, CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into product_categories (id, code, name, sort_order)
				values (?, 'booking-e5-it', 'Booking E5 測試分類', 991)
				""", CATEGORY_ID);
		jdbcTemplate.update("""
				insert into equipment_items (id, category_id, name, description, active)
				values (?, ?, 'E5 測試桌椅', '會員查詢整合測試', true)
				""", ITEM_ID, CATEGORY_ID);
		jdbcTemplate.update("""
				insert into rental_skus (id, item_id, status)
				values (?, ?, 'active')
				""", RENTAL_SKU_ID, ITEM_ID);
		jdbcTemplate.update("""
				insert into rental_sku_variants (
				    id, rental_sku_id, sku, color, size, specification, status
				)
				values (?, ?, 'RENTAL-E5', null, null, '雙人組', 'active')
				""", VARIANT_ID, RENTAL_SKU_ID);
		jdbcTemplate.update("""
				insert into inventory_locations (
				    id, code, inventory_domain, type, branch_id, name, active
				)
				values (?, 'BOOKING-E5', 'rental', 'campground', null, 'E5 租借庫位', true)
				""", LOCATION_ID);
		jdbcTemplate.update("""
				insert into campground_rental_locations (campground_id, location_id)
				values (?, ?)
				""", CAMPGROUND_ID, LOCATION_ID);
		jdbcTemplate.update("""
				insert into rental_listings (
				    id, campground_id, rental_sku_variant_id,
				    price_per_day_weekday, price_per_day_holiday,
				    discount, description, active
				)
				values (?, ?, ?, 200.00, 300.00, 0.10, 'E5 listing', true)
				""", LISTING_ID, CAMPGROUND_ID, VARIANT_ID);
	}

	private void insertCustomer(String customerId, String email, String firebaseUid) {
		jdbcTemplate.update("""
				insert into customers (
				    id, name, phone, email, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid,
				    created_at, updated_at, status
				)
				values (?, 'Booking E5 Tester', '0912345678', ?, now(), 0,
				        false, 'google', ?, now(), now(), 'active')
				on conflict (id) do update set
				    name = excluded.name,
				    phone = excluded.phone,
				    email = excluded.email,
				    firebase_uid = excluded.firebase_uid,
				    updated_at = now()
				""", customerId, email, firebaseUid);
		jdbcTemplate.queryForObject("select reactivate_customer(?)", Boolean.class, customerId);
	}

	// 測試資料使用 E-5 專屬 ID，避免依賴開發 seed 或污染其他測試。
	private void removeTestData() {
		jdbcTemplate.update("delete from bookings where campground_id = ?", CAMPGROUND_ID);
		jdbcTemplate.update("delete from rental_listings where id = ?", LISTING_ID);
		jdbcTemplate.update("delete from campground_rental_locations where campground_id = ?", CAMPGROUND_ID);
		jdbcTemplate.update("delete from campground_zones where id = ?", ZONE_ID);
		jdbcTemplate.update("delete from campgrounds where id = ?", CAMPGROUND_ID);
		jdbcTemplate.update("delete from inventory_locations where id = ?", LOCATION_ID);
		jdbcTemplate.update("delete from rental_sku_variants where id = ?", VARIANT_ID);
		jdbcTemplate.update("delete from rental_skus where id = ?", RENTAL_SKU_ID);
		jdbcTemplate.update("delete from equipment_items where id = ?", ITEM_ID);
		jdbcTemplate.update("delete from product_categories where id = ?", CATEGORY_ID);

		softDeleteIfPresent(CUSTOMER_A);
		softDeleteIfPresent(CUSTOMER_B);
	}

	private void softDeleteIfPresent(String customerId) {
		Integer count = jdbcTemplate.queryForObject(
				"select count(*) from customers where id = ? and status <> 'deleted'",
				Integer.class,
				customerId);
		if (count != null && count > 0) {
			jdbcTemplate.queryForObject("select soft_delete_customer(?)", Boolean.class, customerId);
		}
	}
}
