package com.yuruicamp.backend.booking.api;

import static org.hamcrest.Matchers.hasItem;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.time.ZoneId;

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

// 使用真正 PostgreSQL 驗收公休、停售與 pending 預約都會影響跨日最低可用量。
@SpringBootTest
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@Transactional
class BookingAvailabilityIntegrationTest {

	private static final String CAMPGROUND_ID = "C-BOOKING-E2-IT";
	private static final String ZONE_ID = "Z-BOOKING-E2-A";

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	private LocalDate today;
	private LocalDate closureStart;
	private LocalDate blockStart;
	private LocalDate occupiedStart;
	private LocalDate confirmedStart;
	private LocalDate multiNightStart;

	@BeforeEach
	void setUp() {
		today = LocalDate.now(ZoneId.of("Asia/Taipei"));
		closureStart = today.plusDays(20);
		blockStart = today.plusDays(30);
		occupiedStart = today.plusDays(40);
		confirmedStart = today.plusDays(45);
		multiNightStart = today.plusDays(50);

		jdbcTemplate.update("""
				insert into admin_users (id, name, email, role, active)
				values ('ADMIN-BOOKING-E2-IT', 'Booking E2 測試管理員',
				        'booking-e2-it@example.invalid', 'admin', true)
				""");
		jdbcTemplate.update("""
				insert into customers
				       (id, name, email, registered_at, auth_provider, status)
				values ('CUSTOMER-BOOKING-E2-IT', 'Booking E2 測試會員',
				        'booking-e2-customer@example.invalid', now(), 'google', 'active')
				""");
		jdbcTemplate.update("""
				insert into campgrounds (id, name, region, description, active)
				values (?, 'E2 測試營區', '測試區域', '可用性整合測試營區', true)
				""", CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into campground_zones
				       (id, campground_id, type, capacity_per_site,
				        price_weekday, price_holiday, total_sites, active)
				values (?, ?, '草地區', 4, 1200.00, 1500.00, 5, true)
				""", ZONE_ID, CAMPGROUND_ID);

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
				insert into campground_closures
				       (id, campground_id, closure_type, start_date, end_date,
				        weekday, effective_from, effective_to, reason, created_by)
				values (990101, ?, 'date_range', ?, ?, null, null, null,
				        'E2 公休測試', 'ADMIN-BOOKING-E2-IT')
				""", CAMPGROUND_ID, closureStart, closureStart.plusDays(1));
		jdbcTemplate.update("""
				insert into zone_blocks
				       (id, campground_id, zone_id, start_date, end_date,
				        blocked_quantity, reason, created_by)
				values (990102, ?, ?, ?, ?, 4, 'E2 單晚停售測試', 'ADMIN-BOOKING-E2-IT'),
				       (990103, ?, ?, ?, ?, 4, 'E2 多晚最低量測試', 'ADMIN-BOOKING-E2-IT')
				""",
				CAMPGROUND_ID, ZONE_ID, blockStart, blockStart.plusDays(1),
				CAMPGROUND_ID, ZONE_ID, multiNightStart.plusDays(1), multiNightStart.plusDays(2));

		jdbcTemplate.update("""
				insert into bookings
				       (id, customer_id, campground_id, campground_name_snapshot,
				        region_snapshot, check_in, check_out, guest_count,
				        weekday_count, holiday_count, zone_total, rental_total,
				        applied_discount, final_amount, payment_method,
				        payment_status, checkout_expires_at, status, created_at)
				values ('B-BOOKING-E2-PENDING', 'CUSTOMER-BOOKING-E2-IT', ?,
				        'E2 測試營區', '測試區域', ?, ?, 2, 1, 0,
				        1200.00, 0.00, 0.00, 1200.00, 'ecpay-credit',
				        'unpaid', now() + interval '15 minutes', 'pending', now())
				""", CAMPGROUND_ID, occupiedStart, occupiedStart.plusDays(1));
		jdbcTemplate.update("""
				insert into bookings
				       (id, customer_id, campground_id, campground_name_snapshot,
				        region_snapshot, check_in, check_out, guest_count,
				        weekday_count, holiday_count, zone_total, rental_total,
				        applied_discount, final_amount, payment_method,
				        payment_status, paid_at, status, created_at)
				values ('B-BOOKING-E2-CONFIRMED', 'CUSTOMER-BOOKING-E2-IT', ?,
				        'E2 測試營區', '測試區域', ?, ?, 2, 1, 0,
				        1200.00, 0.00, 0.00, 1200.00, 'ecpay-credit',
				        'paid', now(), 'confirmed', now())
				""", CAMPGROUND_ID, confirmedStart, confirmedStart.plusDays(1));
		jdbcTemplate.update("""
				insert into booking_selected_zones
				       (id, booking_id, zone_id, zone_type_snapshot,
				        price_weekday_snapshot, price_holiday_snapshot, quantity)
				values (990104, 'B-BOOKING-E2-PENDING', ?, '草地區', 1200.00, 1500.00, 4),
				       (990105, 'B-BOOKING-E2-CONFIRMED', ?, '草地區', 1200.00, 1500.00, 4)
				""", ZONE_ID, ZONE_ID);
	}

	@Test
	void normalStayReturnsMinimumAvailabilityWithoutWritingBooking() throws Exception {
		int bookingCountBefore = countBookings();
		LocalDate checkIn = today.plusDays(10);

		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(checkIn, checkIn.plusDays(2), 2)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(true))
				.andExpect(jsonPath("$.data.reasons.length()").value(0))
				.andExpect(jsonPath("$.data.zones[0].zoneId").value(ZONE_ID))
				.andExpect(jsonPath("$.data.zones[0].requested").value(2))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(5));

		org.junit.jupiter.api.Assertions.assertEquals(bookingCountBefore, countBookings());
	}

	@Test
	void equalCheckInAndCheckOutReturnsDateError() throws Exception {
		LocalDate checkIn = today.plusDays(10);

		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(checkIn, checkIn, 1)))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("BOOKING_DATE_INVALID"));
	}

	@Test
	void invalidDateFormatReturnsDateError() throws Exception {
		String body = """
				{
				  "campgroundId": "%s",
				  "checkIn": "2026/10/01",
				  "checkOut": "2026-10-02",
				  "zones": [{"zoneId": "%s", "quantity": 1}]
				}
				""".formatted(CAMPGROUND_ID, ZONE_ID);

		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(body))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("BOOKING_DATE_INVALID"));
	}

	@Test
	void checkInBeyondNinetyDayWindowReturnsWindowError() throws Exception {
		LocalDate checkIn = today.plusDays(91);

		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(checkIn, checkIn.plusDays(1), 1)))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("BOOKING_WINDOW_EXCEEDED"));
	}

	@Test
	void checkInBeforeMinimumLeadDaysReturnsWindowError() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(today, today.plusDays(1), 1)))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("BOOKING_WINDOW_EXCEEDED"));
	}

	@Test
	void stayLongerThanPolicyMaximumReturnsWindowError() throws Exception {
		LocalDate checkIn = today.plusDays(10);

		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(checkIn, checkIn.plusDays(8), 1)))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.error.code").value("BOOKING_WINDOW_EXCEEDED"));
	}

	@Test
	void campgroundClosureMakesStayUnavailable() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(closureStart, closureStart.plusDays(1), 1)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(false))
				.andExpect(jsonPath("$.data.reasons", hasItem("CAMPGROUND_CLOSED")))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(0));
	}

	@Test
	void zoneBlockReducesAvailableQuantity() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(blockStart, blockStart.plusDays(1), 2)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(false))
				.andExpect(jsonPath("$.data.reasons", hasItem("ZONE_UNAVAILABLE")))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(1));
	}

	@Test
	void pendingBookingOccupiesAvailability() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(occupiedStart, occupiedStart.plusDays(1), 2)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(false))
				.andExpect(jsonPath("$.data.reasons", hasItem("ZONE_UNAVAILABLE")))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(1));
	}

	@Test
	void confirmedBookingOccupiesAvailability() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(confirmedStart, confirmedStart.plusDays(1), 2)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(false))
				.andExpect(jsonPath("$.data.reasons", hasItem("ZONE_UNAVAILABLE")))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(1));
	}

	@Test
	void oneInsufficientNightControlsMultiNightMinimum() throws Exception {
		mockMvc.perform(post("/api/booking/check-availability")
				.contentType(MediaType.APPLICATION_JSON)
				.content(request(multiNightStart, multiNightStart.plusDays(3), 2)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.data.available").value(false))
				.andExpect(jsonPath("$.data.reasons", hasItem("ZONE_UNAVAILABLE")))
				.andExpect(jsonPath("$.data.zones[0].availableQuantity").value(1));
	}

	private String request(LocalDate checkIn, LocalDate checkOut, int quantity) {
		return """
				{
				  "campgroundId": "%s",
				  "checkIn": "%s",
				  "checkOut": "%s",
				  "zones": [{"zoneId": "%s", "quantity": %d}]
				}
				""".formatted(CAMPGROUND_ID, checkIn, checkOut, ZONE_ID, quantity);
	}

	private int countBookings() {
		return jdbcTemplate.queryForObject("select count(*) from bookings", Integer.class);
	}
}
