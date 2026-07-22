package com.yuruicamp.backend.booking.infrastructure;

import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

// 鎖定預約並同步寫入狀態歷程與租借履約結果。
@Repository
public class AdminBookingCommandRepository {

	private final JdbcTemplate jdbc;

	public AdminBookingCommandRepository(JdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public Optional<BookingState> lockById(String id) {
		return jdbc.query("""
				select id, status::text, payment_status::text, check_out
				from bookings where id = ? for update
				""", (rs, rowNum) -> new BookingState(
				rs.getString("id"), rs.getString("status"), rs.getString("payment_status"),
				rs.getObject("check_out", LocalDate.class)), id)
				.stream()
				.findFirst();
	}

	public void updateStatus(String id, String status, Instant now) {
		jdbc.update("update bookings set status = ?::booking_status, updated_at = ? where id = ?",
				status, databaseTime(now), id);
	}

	public void fulfillRentalReservations(String id, Instant now) {
		jdbc.update("""
				update rental_stock_reservations reservation
				set status = 'fulfilled', fulfilled_at = ?, released_at = null
				where reservation.status = 'active'
				  and exists (
				      select 1
				      from booking_selected_rentals selected
				      where selected.id = reservation.booking_selected_rental_id
				        and selected.booking_id = ?
				  )
				""", databaseTime(now), id);
	}

	public void addHistory(String id, String status, Instant now, String actorId, String note) {
		jdbc.update("""
				insert into booking_status_history (booking_id, status, occurred_at, actor_id, note)
				values (?, ?::booking_status, ?, ?, ?)
				""", id, status, databaseTime(now), actorId, note);
	}

	// PostgreSQL JDBC 可明確識別 OffsetDateTime，並保存為 timestamptz。
	private static OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record BookingState(String id, String status, String paymentStatus, LocalDate checkOut) {
	}
}
