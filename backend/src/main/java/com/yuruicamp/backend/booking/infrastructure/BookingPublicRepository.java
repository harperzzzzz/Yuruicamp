package com.yuruicamp.backend.booking.infrastructure;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

// Booking 公開查詢使用 PostgreSQL read model，避免把查詢用 View 硬映射成可寫 Entity。
@Repository
public class BookingPublicRepository {

	private final JdbcTemplate jdbcTemplate;

	public BookingPublicRepository(JdbcTemplate jdbcTemplate) {
		this.jdbcTemplate = jdbcTemplate;
	}

	// 只取得可公開預約的有效營區。
	public List<CampgroundRow> findActiveCampgrounds() {
		return jdbcTemplate.query("""
				select id, name, region, description, active
				from campgrounds
				where active = true
				order by id
				""", (rs, rowNum) -> new CampgroundRow(
				rs.getString("id"),
				rs.getString("name"),
				rs.getString("region"),
				rs.getString("description"),
				rs.getBoolean("active")));
	}

	// 依 ID 取得有效營區，停用營區對公開 API 等同不存在。
	public Optional<CampgroundRow> findActiveCampground(String id) {
		return jdbcTemplate.query("""
				select id, name, region, description, active
				from campgrounds
				where id = ? and active = true
				""", (rs, rowNum) -> new CampgroundRow(
				rs.getString("id"),
				rs.getString("name"),
				rs.getString("region"),
				rs.getString("description"),
				rs.getBoolean("active")), id)
				.stream()
				.findFirst();
	}

	// 詳情只載入有效營位，並以 ID 維持穩定順序。
	public List<ZoneRow> findActiveZones(String campgroundId) {
		return jdbcTemplate.query("""
				select id, type, capacity_per_site, price_weekday,
				       price_holiday, total_sites, active
				from campground_zones
				where campground_id = ? and active = true
				order by id
				""", (rs, rowNum) -> new ZoneRow(
				rs.getString("id"),
				rs.getString("type"),
				rs.getInt("capacity_per_site"),
				rs.getBigDecimal("price_weekday"),
				rs.getBigDecimal("price_holiday"),
				rs.getInt("total_sites"),
				rs.getBoolean("active")), campgroundId);
	}

	// 以 active_rental_listing_view 為有效上架真相，再確認營區與租借庫位仍可用。
	public List<RentalEquipmentRow> findActiveRentalEquipment(String campgroundId) {
		return jdbcTemplate.query("""
				select listing.id,
				       listing.rental_sku_variant_id,
				       listing.campground_id,
				       item.name,
				       listing.price_per_day_weekday,
				       listing.price_per_day_holiday
				from active_rental_listing_view listing
				join rental_sku_variants variant on variant.id = listing.rental_sku_variant_id
				join rental_skus sku on sku.id = variant.rental_sku_id
				join equipment_items item on item.id = sku.item_id
				join campgrounds campground on campground.id = listing.campground_id
				join inventory_locations location on location.id = listing.location_id
				where listing.campground_id = ?
				  and campground.active = true
				  and location.active = true
				  and location.inventory_domain = 'rental'
				  and location.type = 'campground'
				order by listing.id
				""", (rs, rowNum) -> new RentalEquipmentRow(
				rs.getString("id"),
				rs.getString("rental_sku_variant_id"),
				rs.getString("campground_id"),
				rs.getString("name"),
				rs.getBigDecimal("price_per_day_weekday"),
				rs.getBigDecimal("price_per_day_holiday")), campgroundId);
	}

	// 政策固定讀取 singleton id=1。
	public Optional<PolicyRow> findPolicy() {
		return jdbcTemplate.query("""
				select booking_window_days, advance_days, max_nights,
				       timezone, date_boundary_hour, low_availability_threshold
				from booking_policies
				where id = 1
				""", (rs, rowNum) -> new PolicyRow(
				rs.getInt("booking_window_days"),
				rs.getInt("advance_days"),
				rs.getInt("max_nights"),
				rs.getString("timezone"),
				rs.getInt("date_boundary_hour"),
				rs.getInt("low_availability_threshold")))
				.stream()
				.findFirst();
	}

	// 占用狀態由資料庫政策決定，不在 Java 寫死。
	public List<String> findOccupyingStatuses() {
		return jdbcTemplate.queryForList("""
				select status::text
				from booking_policy_occupying_statuses
				where policy_id = 1
				order by status::text
				""", String.class);
	}

	// 只公開有效營區的關閉規則。
	public List<ClosureRow> findClosuresForActiveCampgrounds() {
		return jdbcTemplate.query("""
				select closure.id, closure.campground_id, closure.closure_type,
				       closure.start_date, closure.end_date, closure.weekday,
				       closure.effective_from, closure.effective_to, closure.reason
				from campground_closures closure
				join campgrounds campground on campground.id = closure.campground_id
				where campground.active = true
				order by closure.id
				""", (rs, rowNum) -> new ClosureRow(
				rs.getLong("id"),
				rs.getString("campground_id"),
				rs.getString("closure_type"),
				rs.getObject("start_date", LocalDate.class),
				rs.getObject("end_date", LocalDate.class),
				rs.getObject("weekday", Integer.class),
				rs.getObject("effective_from", LocalDate.class),
				rs.getObject("effective_to", LocalDate.class),
				rs.getString("reason")));
	}

	// DB 函式的結束日為包含端點；Service 會傳入退房日前一日。
	public List<ZoneAvailabilityRow> findZoneAvailability(
			LocalDate from,
			LocalDate toInclusive,
			String campgroundId) {
		return jdbcTemplate.query("""
				select zone_id, stay_date, available_quantity, is_closed
				from get_zone_availability(?, ?, ?, null)
				order by zone_id, stay_date
				""", (rs, rowNum) -> new ZoneAvailabilityRow(
				rs.getString("zone_id"),
				rs.getObject("stay_date", LocalDate.class),
				rs.getInt("available_quantity"),
				rs.getBoolean("is_closed")), from, toInclusive, campgroundId);
	}

	public record CampgroundRow(String id, String name, String region, String description, boolean active) {
	}

	public record ZoneRow(
			String id,
			String type,
			int capacityPerSite,
			BigDecimal priceWeekday,
			BigDecimal priceHoliday,
			int totalSites,
			boolean active) {
	}

	public record RentalEquipmentRow(
			String id,
			String rentalSkuVariantId,
			String campgroundId,
			String name,
			BigDecimal pricePerDayWeekday,
			BigDecimal pricePerDayHoliday) {
	}

	public record PolicyRow(
			int bookingWindowDays,
			int advanceDays,
			int maxNights,
			String timezone,
			int dateBoundaryHour,
			int lowAvailabilityThreshold) {
	}

	public record ClosureRow(
			long id,
			String campgroundId,
			String closureType,
			LocalDate startDate,
			LocalDate endDate,
			Integer weekday,
			LocalDate effectiveFrom,
			LocalDate effectiveTo,
			String reason) {
	}

	public record ZoneAvailabilityRow(
			String zoneId,
			LocalDate stayDate,
			int availableQuantity,
			boolean closed) {
	}
}
