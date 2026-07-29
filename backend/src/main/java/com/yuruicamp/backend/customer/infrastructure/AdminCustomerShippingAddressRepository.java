package com.yuruicamp.backend.customer.infrastructure;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.jdbc.support.GeneratedKeyHolder;
import org.springframework.stereotype.Repository;

/**
 * 後台會員預設地址寫入（customer_shipping_addresses）。
 * Admin write access for customer default shipping addresses.
 *
 * 只動地址表；絕不 UPDATE orders 的 shipping_*_snapshot。
 * Touches address table only; never order shipping snapshots.
 */
@Repository
public class AdminCustomerShippingAddressRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminCustomerShippingAddressRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	/**
	 * 鎖定該會員的預設地址列（若存在）。
	 * Lock the customer's default address row when present.
	 */
	public Long lockDefaultAddressId(String customerId) {
		List<Long> ids = jdbc.queryForList("""
				SELECT id FROM customer_shipping_addresses
				WHERE customer_id = :customerId AND is_default = true
				FOR UPDATE
				""", new MapSqlParameterSource("customerId", customerId), Long.class);
		return ids.isEmpty() ? null : ids.getFirst();
	}

	public void updateDefault(
			long id,
			String recipientName,
			String postalCode,
			String city,
			String district,
			String addressLine,
			String phone,
			Instant now) {
		jdbc.update("""
				UPDATE customer_shipping_addresses
				SET recipient_name = :recipientName,
				    postal_code = :postalCode,
				    city = :city,
				    district = :district,
				    address_line = :addressLine,
				    phone = :phone,
				    updated_at = :now
				WHERE id = :id AND is_default = true
				""", new MapSqlParameterSource()
						.addValue("id", id)
						.addValue("recipientName", recipientName)
						.addValue("postalCode", postalCode)
						.addValue("city", city)
						.addValue("district", district)
						.addValue("addressLine", addressLine)
						.addValue("phone", phone)
						.addValue("now", databaseTime(now)));
	}

	/** 新增一筆預設地址。 / Insert a new default address row. */
	public long insertDefault(
			String customerId,
			String recipientName,
			String postalCode,
			String city,
			String district,
			String addressLine,
			String phone,
			Instant now) {
		GeneratedKeyHolder keyHolder = new GeneratedKeyHolder();
		jdbc.update("""
				INSERT INTO customer_shipping_addresses (
				    customer_id, recipient_name, postal_code, city, district,
				    address_line, phone, is_default, created_at, updated_at)
				VALUES (
				    :customerId, :recipientName, :postalCode, :city, :district,
				    :addressLine, :phone, true, :now, :now)
				""", new MapSqlParameterSource()
						.addValue("customerId", customerId)
						.addValue("recipientName", recipientName)
						.addValue("postalCode", postalCode)
						.addValue("city", city)
						.addValue("district", district)
						.addValue("addressLine", addressLine)
						.addValue("phone", phone)
						.addValue("now", databaseTime(now)),
				keyHolder,
				new String[] { "id" });
		Number key = keyHolder.getKey();
		if (key == null) {
			throw new IllegalStateException("Failed to insert customer_shipping_addresses row");
		}
		return key.longValue();
	}

	private OffsetDateTime databaseTime(Instant value) {
		return OffsetDateTime.ofInstant(value, ZoneOffset.UTC);
	}
}
