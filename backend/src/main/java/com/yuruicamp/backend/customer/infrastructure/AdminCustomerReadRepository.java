package com.yuruicamp.backend.customer.infrastructure;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.customer.api.AdminCustomerAddressResponse;
import com.yuruicamp.backend.customer.api.AdminCustomerTagResponse;
import com.yuruicamp.backend.customer.domain.CustomerStatus;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台會員專用讀模型，分頁先查 ID，再組合等級與標籤，避免多對多 JOIN 造成重複。
 */
@Repository
public class AdminCustomerReadRepository {

	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"registeredAt", "customer.registered_at",
			"totalSpent", "COALESCE(tier.total_spent, 0)",
			"name", "customer.name",
			"points", "customer.points",
			"updatedAt", "customer.updated_at");

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCustomerReadRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public IdPage findIds(
			int page,
			int size,
			String query,
			String status,
			String tierCode,
			List<Long> tagIds,
			String sortField,
			String sortDirection) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("query", "%" + query.toLowerCase(java.util.Locale.ROOT) + "%")
				.addValue("status", status)
				.addValue("tier", tierCode)
				.addValue("tagIds", tagIds)
				.addValue("limit", size)
				.addValue("offset", page * size);
		String where = buildWhere(status, tierCode, tagIds);
		String from = """
				FROM customers customer
				LEFT JOIN customer_tier_summary tier ON tier.customer_id = customer.id
				""";
		long total = jdbc.queryForObject("SELECT count(*) " + from + where, parameters, Long.class);
		String orderBy = SORT_COLUMNS.get(sortField) + " " + sortDirection + ", customer.id ASC";
		List<String> ids = jdbc.queryForList(
				"SELECT customer.id " + from + where + " ORDER BY " + orderBy + " LIMIT :limit OFFSET :offset",
				parameters,
				String.class);

		return new IdPage(ids, total);
	}

	public List<AdminCustomerRow> findRows(List<String> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		return jdbc.query("""
				SELECT customer.id, customer.name, customer.phone, customer.email,
				       customer.status::text AS status, customer.registered_at,
				       COALESCE(tier.tier_code, 'explorer') AS tier_code,
				       COALESCE(tier.tier_name, '探險家') AS tier_name,
				       COALESCE(tier.total_spent, 0) AS total_spent, customer.points
				FROM customers customer
				LEFT JOIN customer_tier_summary tier ON tier.customer_id = customer.id
				WHERE customer.id IN (:ids)
				""", new MapSqlParameterSource("ids", ids), this::mapRow);
	}

	public Map<String, List<AdminCustomerTagResponse>> findTags(List<String> customerIds) {
		Map<String, List<AdminCustomerTagResponse>> result = new HashMap<>();
		if (customerIds.isEmpty()) {
			return result;
		}
		jdbc.query("""
				SELECT assignment.customer_id, tag.id, tag.name, tag.color
				FROM customer_tag_assignments assignment
				JOIN customer_tags tag ON tag.id = assignment.tag_id
				WHERE assignment.customer_id IN (:ids) AND tag.active = true
				ORDER BY tag.sort_order, tag.id
				""", new MapSqlParameterSource("ids", customerIds), row -> {
			String customerId = row.getString("customer_id");
			result.computeIfAbsent(customerId, ignored -> new java.util.ArrayList<>())
					.add(new AdminCustomerTagResponse(
							row.getLong("id"),
							row.getString("name"),
							row.getString("color")));
		});

		return result;
	}

	public Map<String, List<String>> findPreferences(String customerId) {
		Map<String, List<String>> preferences = new java.util.LinkedHashMap<>();
		preferences.put("styles", new java.util.ArrayList<>());
		preferences.put("equipment", new java.util.ArrayList<>());
		jdbc.query("""
				SELECT option.type, option.code
				FROM customer_preferences preference
				JOIN preference_options option ON option.id = preference.preference_id
				WHERE preference.customer_id = :id AND option.active = true
				ORDER BY option.sort_order, option.id
				""", new MapSqlParameterSource("id", customerId), row -> {
			String key = "style".equals(row.getString("type")) ? "styles" : "equipment";
			preferences.get(key).add(row.getString("code"));
		});

		return preferences;
	}

	public AdminCustomerAddressResponse findDefaultAddress(String customerId) {
		List<AdminCustomerAddressResponse> addresses = jdbc.query("""
				SELECT id, recipient_name, postal_code, city, district, address_line, phone
				FROM customer_shipping_addresses
				WHERE customer_id = :id AND is_default = true
				""", new MapSqlParameterSource("id", customerId), (row, rowNumber) ->
				new AdminCustomerAddressResponse(
						row.getLong("id"), row.getString("recipient_name"), row.getString("postal_code"),
						row.getString("city"), row.getString("district"), row.getString("address_line"),
						row.getString("phone")));

		return addresses.isEmpty() ? null : addresses.getFirst();
	}

	public long countOrders(String customerId) {
		return jdbc.queryForObject(
				"SELECT count(*) FROM orders WHERE customer_id = :id",
				new MapSqlParameterSource("id", customerId),
				Long.class);
	}

	public long countBookings(String customerId) {
		return jdbc.queryForObject(
				"SELECT count(*) FROM bookings WHERE customer_id = :id",
				new MapSqlParameterSource("id", customerId),
				Long.class);
	}

	private String buildWhere(String status, String tierCode, List<Long> tagIds) {
		StringBuilder where = new StringBuilder("""
				 WHERE (lower(customer.id) LIKE :query
				    OR lower(customer.name) LIKE :query
				    OR lower(customer.email) LIKE :query
				    OR lower(COALESCE(customer.phone, '')) LIKE :query)
				""");
		if (!status.isBlank()) {
			where.append(" AND customer.status::text = :status");
		}
		if (!tierCode.isBlank()) {
			where.append(" AND COALESCE(tier.tier_code, 'explorer') = :tier");
		}
		if (!tagIds.isEmpty()) {
			where.append("""
					 AND EXISTS (
					     SELECT 1 FROM customer_tag_assignments assignment
					     WHERE assignment.customer_id = customer.id AND assignment.tag_id IN (:tagIds))
					""");
		}

		return where.toString();
	}

	private AdminCustomerRow mapRow(ResultSet row, int rowNumber) throws SQLException {
		return new AdminCustomerRow(
				row.getString("id"),
				row.getString("name"),
				row.getString("phone"),
				row.getString("email"),
				CustomerStatus.valueOf(row.getString("status")),
				row.getObject("registered_at", java.time.OffsetDateTime.class).toInstant(),
				row.getString("tier_code"),
				row.getString("tier_name"),
				row.getObject("total_spent", BigDecimal.class),
				row.getInt("points"));
	}

	public record IdPage(List<String> ids, long totalElements) {
	}

	public static String resolveSortColumn(String sortField) {
		return SORT_COLUMNS.get(sortField);
	}
}
