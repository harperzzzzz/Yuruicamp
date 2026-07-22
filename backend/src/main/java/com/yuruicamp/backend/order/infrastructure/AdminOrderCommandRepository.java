package com.yuruicamp.backend.order.infrastructure;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

// 鎖定訂單並以單一交易寫入履約狀態與操作歷程。
@Repository
public class AdminOrderCommandRepository {

	private final JdbcTemplate jdbc;

	public AdminOrderCommandRepository(JdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public Optional<OrderState> lockById(String id) {
		return jdbc.query("""
				select id, status::text, payment_method::text, payment_status::text, refund_status::text
				from orders where id = ? for update
				""", (rs, rowNum) -> new OrderState(
				rs.getString("id"), rs.getString("status"), rs.getString("payment_method"),
				rs.getString("payment_status"), rs.getString("refund_status")), id)
				.stream()
				.findFirst();
	}

	public void updateStatus(String id, String status, Instant now) {
		jdbc.update("update orders set status = ?::order_status, updated_at = ? where id = ?",
				status, databaseTime(now), id);
	}

	public void completeCod(String id, Instant now) {
		OffsetDateTime occurredAt = databaseTime(now);

		jdbc.update("""
				update orders
				set status = 'completed', payment_status = 'paid', paid_at = coalesce(paid_at, ?), updated_at = ?
				where id = ?
				""", occurredAt, occurredAt, id);
	}

	public void addHistory(String id, String status, Instant now, String actorId, String note) {
		jdbc.update("""
				insert into order_status_history (order_id, status, occurred_at, actor_id, note)
				values (?, ?::order_status, ?, ?, ?)
				""", id, status, databaseTime(now), actorId, note);
	}

	// PostgreSQL JDBC 可明確識別 OffsetDateTime，並保存為 timestamptz。
	private static OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}

	public record OrderState(
			String id,
			String status,
			String paymentMethod,
			String paymentStatus,
			String refundStatus) {
	}
}
