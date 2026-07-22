package com.yuruicamp.backend.booking.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import com.yuruicamp.backend.booking.api.BookingCheckoutCreateRequest;
import com.yuruicamp.backend.booking.api.BookingCheckoutSessionResponse;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestInstance;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

// 使用真正 PostgreSQL 驗證 E-4 租借跨日保留、狀態過濾與併發防超租。
@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@TestInstance(TestInstance.Lifecycle.PER_CLASS)
class BookingRentalCheckoutIntegrationTest {

	private static final String CAMPGROUND_ID = "C-BOOKING-E4-IT";
	private static final String OTHER_CAMPGROUND_ID = "C-BOOKING-E4-O";
	private static final String ZONE_ID = "Z-BOOKING-E4-A";
	private static final String CUSTOMER_A = "C-BOOKING-E4-A";
	private static final String CUSTOMER_B = "C-BOOKING-E4-B";
	private static final long CATEGORY_ID = 990401L;
	private static final String ITEM_ID = "E-RENTAL-E4-IT";
	private static final String RENTAL_SKU_ID = "RS-E4-IT";
	private static final String VARIANT_ID = "RSV-E4-A";
	private static final String LISTING_ID = "RL-E4-A";
	private static final String OTHER_LISTING_ID = "RL-E4-OTHER";
	private static final String LOCATION_ID = "L-BOOKING-E4-A";
	private static final String OTHER_LOCATION_ID = "L-BOOKING-E4-O";

	@Autowired
	private BookingCheckoutService service;

	@Autowired
	private JdbcTemplate jdbcTemplate;

	private LocalDate checkIn;
	private PolicySnapshot originalPolicy;
	private List<String> originalOccupyingStatuses;

	@BeforeAll
	void rememberBookingPolicy() {
		originalPolicy = jdbcTemplate.query("""
				select booking_window_days, advance_days, max_nights,
				       timezone, date_boundary_hour, low_availability_threshold
				from booking_policies
				where id = 1
				""", (rs, rowNum) -> new PolicySnapshot(
				rs.getInt("booking_window_days"),
				rs.getInt("advance_days"),
				rs.getInt("max_nights"),
				rs.getString("timezone"),
				rs.getInt("date_boundary_hour"),
				rs.getInt("low_availability_threshold")))
				.stream()
				.findFirst()
				.orElse(null);
		originalOccupyingStatuses = jdbcTemplate.queryForList("""
				select status::text
				from booking_policy_occupying_statuses
				where policy_id = 1
				order by status::text
				""", String.class);
	}

	@BeforeEach
	void prepareDatabase() {
		removeTestData();

		checkIn = findUnlistedCalendarRange();
		insertCustomer(CUSTOMER_A, "booking-e4-a@example.invalid", "booking-e4-a");
		insertCustomer(CUSTOMER_B, "booking-e4-b@example.invalid", "booking-e4-b");
		insertBookingReferenceData();
		insertRentalData();
	}

	@AfterEach
	void cleanDatabase() {
		removeTestData();
	}

	@AfterAll
	void restoreBookingPolicy() {
		jdbcTemplate.update("delete from booking_policy_occupying_statuses where policy_id = 1");

		if (originalPolicy == null) {
			jdbcTemplate.update("delete from booking_policies where id = 1");
			return;
		}

		jdbcTemplate.update("""
				update booking_policies
				set booking_window_days = ?, advance_days = ?, max_nights = ?,
				    timezone = ?, date_boundary_hour = ?, low_availability_threshold = ?,
				    updated_at = now()
				where id = 1
				""",
				originalPolicy.bookingWindowDays(),
				originalPolicy.advanceDays(),
				originalPolicy.maxNights(),
				originalPolicy.timezone(),
				originalPolicy.dateBoundaryHour(),
				originalPolicy.lowAvailabilityThreshold());
		originalOccupyingStatuses.forEach(status -> jdbcTemplate.update("""
				insert into booking_policy_occupying_statuses (policy_id, status)
				values (1, ?::booking_status)
				""", status));
	}

	@Test
	void checkoutWithoutRentalStillCreatesBooking() {
		BookingCheckoutSessionResponse response = service.create(
				CUSTOMER_A,
				request("no-rental-" + UUID.randomUUID(), checkIn, checkIn.plusDays(2), List.of()));

		assertThat(response.rentals()).isEmpty();
		assertThat(response.pricing().rentalTotal()).isEqualTo("0.00");
		assertThat(countReservations()).isZero();
	}

	@Test
	void sufficientRentalCreatesSnapshotReservationAndBackendTotal() {
		BookingCheckoutSessionResponse response = service.create(
				CUSTOMER_A,
				request(
						"rental-success-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(LISTING_ID, VARIANT_ID, 2))));

		assertThat(response.pricing().zoneTotal()).isEqualTo("2500.00");
		assertThat(response.pricing().rentalTotal()).isEqualTo("540.00");
		assertThat(response.pricing().finalAmount()).isEqualTo("3040.00");
		assertThat(response.rentals()).singleElement()
				.satisfies(item -> {
					assertThat(item.rentalListingId()).isEqualTo(LISTING_ID);
					assertThat(item.rentalSkuVariantId()).isEqualTo(VARIANT_ID);
					assertThat(item.sku()).isEqualTo("RENTAL-E4-A");
					assertThat(item.name()).isEqualTo("E4 測試租借椅");
					assertThat(item.specification()).isEqualTo("森林綠 / 單人");
					assertThat(item.priceWeekday()).isEqualTo("100.00");
					assertThat(item.priceHoliday()).isEqualTo("200.00");
					assertThat(item.discountRate()).isEqualTo("0.10");
					assertThat(item.lineTotal()).isEqualTo("540.00");
				});

		var selected = jdbcTemplate.queryForMap("""
				select sku_snapshot, name_snapshot, specification_snapshot,
				       price_weekday_snapshot, price_holiday_snapshot,
				       discount_snapshot, quantity
				from booking_selected_rentals
				where booking_id = ?
				""", response.bookingId());
		var reservation = jdbcTemplate.queryForMap("""
				select location_id, check_in, check_out, quantity, status,
				       idempotency_key, inventory_domain
				from rental_stock_reservations
				where booking_selected_rental_id = (
				    select id from booking_selected_rentals where booking_id = ?
				)
				""", response.bookingId());

		assertThat(selected.get("sku_snapshot")).isEqualTo("RENTAL-E4-A");
		assertThat(selected.get("discount_snapshot")).isEqualTo(new BigDecimal("0.10"));
		assertThat(selected.get("quantity")).isEqualTo(2);
		assertThat(reservation.get("location_id")).isEqualTo(LOCATION_ID);
		assertThat(reservation.get("check_in")).isEqualTo(java.sql.Date.valueOf(checkIn));
		assertThat(reservation.get("check_out")).isEqualTo(java.sql.Date.valueOf(checkIn.plusDays(2)));
		assertThat(reservation.get("status")).isEqualTo("active");
		assertThat(reservation.get("inventory_domain")).isEqualTo("rental");
		assertThat(reservation.get("idempotency_key"))
				.isEqualTo(response.bookingId() + ":rental:" + LISTING_ID);
	}

	@Test
	void rentalStockInsufficientRollsBackWholeBooking() {
		assertRentalError(
				CUSTOMER_A,
				request(
						"insufficient-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(LISTING_ID, VARIANT_ID, 4))),
				ErrorCode.RENTAL_STOCK_INSUFFICIENT);

		assertThat(countBookings()).isZero();
		assertThat(countReservations()).isZero();
	}

	@Test
	void nonOverlappingDatesCanReuseSamePhysicalStock() {
		service.create(CUSTOMER_A, request(
				"non-overlap-a-" + UUID.randomUUID(),
				checkIn,
				checkIn.plusDays(2),
				List.of(rental(LISTING_ID, VARIANT_ID, 3))));
		service.create(CUSTOMER_B, request(
				"non-overlap-b-" + UUID.randomUUID(),
				checkIn.plusDays(2),
				checkIn.plusDays(4),
				List.of(rental(LISTING_ID, VARIANT_ID, 3))));

		assertThat(countBookings()).isEqualTo(2);
		assertThat(countReservations()).isEqualTo(2);
	}

	@Test
	void overlappingDatesCannotRentBeyondStock() {
		service.create(CUSTOMER_A, request(
				"overlap-a-" + UUID.randomUUID(),
				checkIn,
				checkIn.plusDays(2),
				List.of(rental(LISTING_ID, VARIANT_ID, 2))));

		assertRentalError(
				CUSTOMER_B,
				request(
						"overlap-b-" + UUID.randomUUID(),
						checkIn.plusDays(1),
						checkIn.plusDays(3),
						List.of(rental(LISTING_ID, VARIANT_ID, 2))),
				ErrorCode.RENTAL_STOCK_INSUFFICIENT);
		assertThat(countBookings()).isEqualTo(1);
		assertThat(countReservations()).isEqualTo(1);
	}

	@Test
	void listingCampgroundVariantAndActiveStatesMustMatch() {
		assertRentalError(
				CUSTOMER_A,
				request(
						"wrong-camp-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(OTHER_LISTING_ID, VARIANT_ID, 1))),
				ErrorCode.NOT_FOUND);
		assertRentalError(
				CUSTOMER_A,
				request(
						"wrong-variant-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(LISTING_ID, "RSV-NOT-MATCHED", 1))),
				ErrorCode.NOT_FOUND);

		jdbcTemplate.update("update rental_listings set active = false where id = ?", LISTING_ID);
		assertInactiveRentalRejected("inactive-listing-" + UUID.randomUUID());
		jdbcTemplate.update("update rental_listings set active = true where id = ?", LISTING_ID);
		jdbcTemplate.update("update rental_sku_variants set status = 'inactive' where id = ?", VARIANT_ID);
		assertInactiveRentalRejected("inactive-variant-" + UUID.randomUUID());
		jdbcTemplate.update("update rental_sku_variants set status = 'active' where id = ?", VARIANT_ID);
		jdbcTemplate.update("update rental_skus set status = 'inactive' where id = ?", RENTAL_SKU_ID);
		assertInactiveRentalRejected("inactive-sku-" + UUID.randomUUID());

		assertThat(countBookings()).isZero();
	}

	@Test
	void rentalParticipatesInIdempotencyFingerprint() {
		String key = "rental-idempotency-" + UUID.randomUUID();
		BookingCheckoutSessionResponse created = service.create(
				CUSTOMER_A,
				request(key, checkIn, checkIn.plusDays(2), List.of(rental(LISTING_ID, VARIANT_ID, 1))));
		BookingCheckoutSessionResponse replay = service.create(
				CUSTOMER_A,
				request(key, checkIn, checkIn.plusDays(2), List.of(rental(LISTING_ID, VARIANT_ID, 1))));

		assertThat(replay.bookingId()).isEqualTo(created.bookingId());
		assertRentalError(
				CUSTOMER_A,
				request(key, checkIn, checkIn.plusDays(2), List.of(rental(LISTING_ID, VARIANT_ID, 2))),
				ErrorCode.IDEMPOTENCY_CONFLICT);
		assertThat(countBookings()).isEqualTo(1);
		assertThat(countReservations()).isEqualTo(1);
	}

	@Test
	void twoTransactionsCompetingForLastRentalCreateOnlyOneReservation() throws Exception {
		jdbcTemplate.update("""
				update rental_sku_variant_stocks
				set on_hand_quantity = 1
				where location_id = ? and rental_sku_variant_id = ?
				""", LOCATION_ID, VARIANT_ID);
		CountDownLatch ready = new CountDownLatch(2);
		CountDownLatch start = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);

		try {
			Future<BookingCheckoutSessionResponse> resultA = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.create(CUSTOMER_A, request(
						"rental-race-a-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(LISTING_ID, VARIANT_ID, 1))));
			});
			Future<BookingCheckoutSessionResponse> resultB = executor.submit(() -> {
				ready.countDown();
				start.await();
				return service.create(CUSTOMER_B, request(
						"rental-race-b-" + UUID.randomUUID(),
						checkIn,
						checkIn.plusDays(2),
						List.of(rental(LISTING_ID, VARIANT_ID, 1))));
			});

			ready.await();
			start.countDown();

			int successes = completedSuccessfully(resultA) + completedSuccessfully(resultB);
			assertThat(successes).isEqualTo(1);
			assertRentalUnavailableIfFailed(resultA);
			assertRentalUnavailableIfFailed(resultB);
			assertThat(countBookings()).isEqualTo(1);
			assertThat(countReservations()).isEqualTo(1);
		}
		finally {
			executor.shutdownNow();
		}
	}

	private BookingCheckoutCreateRequest request(
			String key,
			LocalDate requestedCheckIn,
			LocalDate requestedCheckOut,
			List<BookingCheckoutCreateRequest.Rental> rentals) {
		return new BookingCheckoutCreateRequest(
				CAMPGROUND_ID,
				requestedCheckIn.toString(),
				requestedCheckOut.toString(),
				2,
				List.of(new BookingCheckoutCreateRequest.Zone(ZONE_ID, 1)),
				rentals,
				null,
				"ecpay-credit",
				key);
	}

	private BookingCheckoutCreateRequest.Rental rental(
			String listingId,
			String variantId,
			int quantity) {
		return new BookingCheckoutCreateRequest.Rental(listingId, variantId, quantity);
	}

	private void assertInactiveRentalRejected(String key) {
		assertRentalError(
				CUSTOMER_A,
				request(key, checkIn, checkIn.plusDays(2), List.of(rental(LISTING_ID, VARIANT_ID, 1))),
				ErrorCode.NOT_FOUND);
	}

	private void assertRentalError(
			String customerId,
			BookingCheckoutCreateRequest request,
			ErrorCode expected) {
		assertThatThrownBy(() -> service.create(customerId, request))
				.isInstanceOf(BusinessException.class)
				.satisfies(ex -> assertThat(((BusinessException) ex).getErrorCode()).isEqualTo(expected));
	}

	private int completedSuccessfully(Future<BookingCheckoutSessionResponse> result) {
		try {
			return result.get() == null ? 0 : 1;
		}
		catch (InterruptedException ex) {
			Thread.currentThread().interrupt();
			throw new AssertionError("等待租借 Checkout 測試時被中斷", ex);
		}
		catch (ExecutionException ex) {
			return 0;
		}
	}

	private void assertRentalUnavailableIfFailed(Future<BookingCheckoutSessionResponse> result) {
		try {
			result.get();
		}
		catch (InterruptedException ex) {
			Thread.currentThread().interrupt();
			throw new AssertionError("等待租借 Checkout 測試時被中斷", ex);
		}
		catch (ExecutionException ex) {
			assertThat(ex.getCause()).isInstanceOf(BusinessException.class);
			assertThat(((BusinessException) ex.getCause()).getErrorCode())
					.isEqualTo(ErrorCode.RENTAL_STOCK_INSUFFICIENT);
		}
	}

	private int countBookings() {
		return jdbcTemplate.queryForObject(
				"select count(*) from bookings where campground_id = ?",
				Integer.class,
				CAMPGROUND_ID);
	}

	private int countReservations() {
		return jdbcTemplate.queryForObject("""
				select count(*)
				from rental_stock_reservations
				where location_id = ? and rental_sku_variant_id = ?
				""", Integer.class, LOCATION_ID, VARIANT_ID);
	}

	private LocalDate findUnlistedCalendarRange() {
		LocalDate today = LocalDate.now(ZoneId.of("Asia/Taipei"));

		for (int offset = 10; offset <= 80; offset++) {
			LocalDate candidate = today.plusDays(offset);
			Integer rows = jdbcTemplate.queryForObject("""
					select count(*)
					from calendar_dates
					where calendar_date >= ? and calendar_date < ?
					""", Integer.class, candidate, candidate.plusDays(4));

			if (rows != null && rows == 0) {
				return candidate;
			}
		}

		throw new IllegalStateException("No free calendar range is available for Booking E-4 test");
	}

	private void insertBookingReferenceData() {
		jdbcTemplate.update("""
				insert into campgrounds (id, name, region, description, active)
				values (?, 'E4 測試營區', '測試區域', '租借 Checkout 測試', true),
				       (?, 'E4 其他營區', '其他區域', '營區不符測試', true)
				""", CAMPGROUND_ID, OTHER_CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into campground_zones (
				    id, campground_id, type, capacity_per_site,
				    price_weekday, price_holiday, total_sites, active
				)
				values (?, ?, '草地區', 4, 1000.00, 1500.00, 5, true)
				""", ZONE_ID, CAMPGROUND_ID);
		jdbcTemplate.update("""
				insert into booking_policies (
				    id, booking_window_days, advance_days, max_nights,
				    timezone, date_boundary_hour, low_availability_threshold
				)
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
				insert into calendar_dates (
				    calendar_date, is_holiday, holiday_name, source_version, effective_at
				)
				values (?, true, 'E4 測試假日', 'booking-e4-it', now())
				""", checkIn.plusDays(1));
	}

	private void insertRentalData() {
		jdbcTemplate.update("""
				insert into product_categories (id, code, name, sort_order)
				values (?, 'booking-e4-it', 'Booking E4 測試分類', 990)
				""", CATEGORY_ID);
		jdbcTemplate.update("""
				insert into equipment_items (id, category_id, name, description, active)
				values (?, ?, 'E4 測試租借椅', '租借 Checkout 整合測試', true)
				""", ITEM_ID, CATEGORY_ID);
		jdbcTemplate.update("""
				insert into rental_skus (id, item_id, status)
				values (?, ?, 'active')
				""", RENTAL_SKU_ID, ITEM_ID);
		jdbcTemplate.update("""
				insert into rental_sku_variants (
				    id, rental_sku_id, sku, color, size, specification, status
				)
				values (?, ?, 'RENTAL-E4-A', '森林綠', null, '森林綠 / 單人', 'active')
				""", VARIANT_ID, RENTAL_SKU_ID);
		jdbcTemplate.update("""
				insert into inventory_locations (
				    id, code, inventory_domain, type, branch_id, name, active
				)
				values (?, 'BOOKING-E4-A', 'rental', 'campground', null, 'E4 測試租借庫位', true),
				       (?, 'BOOKING-E4-O', 'rental', 'campground', null, 'E4 其他租借庫位', true)
				""", LOCATION_ID, OTHER_LOCATION_ID);
		jdbcTemplate.update("""
				insert into campground_rental_locations (campground_id, location_id)
				values (?, ?), (?, ?)
				""", CAMPGROUND_ID, LOCATION_ID, OTHER_CAMPGROUND_ID, OTHER_LOCATION_ID);
		jdbcTemplate.update("""
				insert into rental_listings (
				    id, campground_id, rental_sku_variant_id,
				    price_per_day_weekday, price_per_day_holiday,
				    discount, description, active
				)
				values (?, ?, ?, 100.00, 200.00, 0.10, 'E4 主 listing', true),
				       (?, ?, ?, 100.00, 200.00, 0.10, 'E4 其他營區 listing', true)
				""",
				LISTING_ID,
				CAMPGROUND_ID,
				VARIANT_ID,
				OTHER_LISTING_ID,
				OTHER_CAMPGROUND_ID,
				VARIANT_ID);
		jdbcTemplate.update("""
				insert into rental_sku_variant_stocks (
				    location_id, rental_sku_variant_id, on_hand_quantity
				)
				values (?, ?, 3), (?, ?, 3)
				""", LOCATION_ID, VARIANT_ID, OTHER_LOCATION_ID, VARIANT_ID);
	}

	private void insertCustomer(String customerId, String email, String firebaseUid) {
		jdbcTemplate.update("""
				insert into customers (
				    id, name, phone, email, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid,
				    created_at, updated_at, status
				)
				values (?, 'Booking E4 Tester', '0912345678', ?, now(), 0,
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

	// 測試資料使用 E-4 專屬 ID，清除時遵守保留帳與主檔外鍵順序。
	private void removeTestData() {
		jdbcTemplate.update("""
				delete from rental_stock_reservations
				where location_id in (?, ?)
				""", LOCATION_ID, OTHER_LOCATION_ID);
		jdbcTemplate.update("""
				delete from bookings
				where campground_id in (?, ?)
				""", CAMPGROUND_ID, OTHER_CAMPGROUND_ID);
		jdbcTemplate.update("delete from rental_listings where id in (?, ?)", LISTING_ID, OTHER_LISTING_ID);
		jdbcTemplate.update("""
				delete from rental_sku_variant_stocks
				where location_id in (?, ?)
				""", LOCATION_ID, OTHER_LOCATION_ID);
		jdbcTemplate.update("""
				delete from campground_rental_locations
				where campground_id in (?, ?)
				""", CAMPGROUND_ID, OTHER_CAMPGROUND_ID);
		jdbcTemplate.update("delete from campground_zones where campground_id = ?", CAMPGROUND_ID);
		jdbcTemplate.update("delete from campgrounds where id in (?, ?)", CAMPGROUND_ID, OTHER_CAMPGROUND_ID);
		jdbcTemplate.update("delete from inventory_locations where id in (?, ?)", LOCATION_ID, OTHER_LOCATION_ID);
		jdbcTemplate.update("delete from rental_sku_variants where id = ?", VARIANT_ID);
		jdbcTemplate.update("delete from rental_skus where id = ?", RENTAL_SKU_ID);
		jdbcTemplate.update("delete from equipment_items where id = ?", ITEM_ID);
		jdbcTemplate.update("delete from product_categories where id = ?", CATEGORY_ID);
		jdbcTemplate.update("delete from calendar_dates where source_version = 'booking-e4-it'");
		jdbcTemplate.queryForObject("select soft_delete_customer(?)", Boolean.class, CUSTOMER_A);
		jdbcTemplate.queryForObject("select soft_delete_customer(?)", Boolean.class, CUSTOMER_B);
	}

	private record PolicySnapshot(
			int bookingWindowDays,
			int advanceDays,
			int maxNights,
			String timezone,
			int dateBoundaryHour,
			int lowAvailabilityThreshold) {
	}
}
