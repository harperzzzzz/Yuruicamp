package com.yuruicamp.backend.booking.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

// E-6 以資料庫鎖保護 Booking 取消、付款與逾時處理的狀態競爭。
@Repository
public class BookingLifecycleRepository {

	private final JdbcTemplate jdbcTemplate;

	public BookingLifecycleRepository(JdbcTemplate jdbcTemplate) {
		this.jdbcTemplate = jdbcTemplate;
	}

	// 主動取消同時限制 bookingId 與 customerId，避免讀到別人的預約。
	public Optional<LockedBookingRow> lockOwnedBooking(String customerId, String bookingId) {
		return jdbcTemplate.query("""
				select id, customer_id, status::text, payment_status::text, checkout_expires_at
				from bookings
				where id = ? and customer_id = ?
				for update
				""", (rs, rowNum) -> toLockedBooking(rs), bookingId, customerId)
				.stream()
				.findFirst();
	}

	// 排程鎖定候選 Booking 後仍會重新檢查狀態，避免覆蓋剛完成的付款。
	public Optional<LockedBookingRow> lockBooking(String bookingId) {
		return jdbcTemplate.query("""
				select id, customer_id, status::text, payment_status::text, checkout_expires_at
				from bookings
				where id = ?
				for update
				""", (rs, rowNum) -> toLockedBooking(rs), bookingId)
				.stream()
				.findFirst();
	}

	public List<String> findDueBookingIds(Instant now) {
		return jdbcTemplate.queryForList("""
				select id
				from bookings
				where checkout_expires_at is not null
				  and checkout_expires_at <= ?
				  and status = 'pending'
				  and payment_status = 'unpaid'
				order by checkout_expires_at, id
				""", String.class, utc(now));
	}

	public void cancelBooking(String bookingId, Instant occurredAt) {
		jdbcTemplate.update("""
				update bookings
				set status = 'cancelled', updated_at = ?
				where id = ?
				""", utc(occurredAt), bookingId);
	}

	// Schema 只允許 released 作為租借取消終態，並要求 released_at 必填。
	public int releaseActiveRentalReservations(String bookingId, Instant releasedAt) {
		return jdbcTemplate.update("""
				update rental_stock_reservations reservation
				set status = 'released', released_at = ?, fulfilled_at = null
				where reservation.status = 'active'
				  and exists (
				      select 1
				      from booking_selected_rentals selected
				      where selected.id = reservation.booking_selected_rental_id
				        and selected.booking_id = ?
				  )
				""", utc(releasedAt), bookingId);
	}

	public void insertCancelledHistory(String bookingId, Instant occurredAt, String note) {
		jdbcTemplate.update("""
				insert into booking_status_history (booking_id, status, occurred_at, actor_id, note)
				values (?, 'cancelled', ?, null, ?)
				""", bookingId, utc(occurredAt), note);
	}

	private LockedBookingRow toLockedBooking(ResultSet rs) throws SQLException {
		OffsetDateTime expiresAt = rs.getObject("checkout_expires_at", OffsetDateTime.class);

		return new LockedBookingRow(
				rs.getString("id"),
				rs.getString("customer_id"),
				rs.getString("status"),
				rs.getString("payment_status"),
				expiresAt == null ? null : expiresAt.toInstant());
	}

	private OffsetDateTime utc(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record LockedBookingRow(
			String id,
			String customerId,
			String status,
			String paymentStatus,
			Instant checkoutExpiresAt) {

		public boolean isPendingUnpaid() {
			return "pending".equals(status) && "unpaid".equals(paymentStatus);
		}

		public boolean isDue(Instant now) {
			return checkoutExpiresAt != null && !checkoutExpiresAt.isAfter(now);
		}
	}
}
