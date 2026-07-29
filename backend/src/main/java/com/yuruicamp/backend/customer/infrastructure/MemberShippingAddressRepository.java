package com.yuruicamp.backend.customer.infrastructure;

import java.util.Optional;

import com.yuruicamp.backend.customer.api.MemberShippingAddressRequest;
import com.yuruicamp.backend.customer.api.MemberShippingAddressResponse;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class MemberShippingAddressRepository {

	private final JdbcTemplate jdbc;

	public MemberShippingAddressRepository(JdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	// 只讀取會員自己的預設地址，Email 由 customers 即時投影。
	public Optional<MemberShippingAddressResponse> findDefault(String customerId) {
		return jdbc.query("""
				select address.id, address.recipient_name, address.postal_code,
				       address.city, address.district, address.address_line,
				       address.phone, customer.email
				from customer_shipping_addresses address
				join customers customer on customer.id = address.customer_id
				where address.customer_id = ? and address.is_default = true
				""", (resultSet, rowNumber) -> new MemberShippingAddressResponse(
				resultSet.getLong("id"),
				resultSet.getString("recipient_name"),
				resultSet.getString("postal_code"),
				resultSet.getString("city"),
				resultSet.getString("district"),
				resultSet.getString("address_line"),
				resultSet.getString("phone"),
				resultSet.getString("email")), customerId)
				.stream()
				.findFirst();
	}

	public void insertDefault(String customerId, MemberShippingAddressRequest request) {
		jdbc.update("""
				insert into customer_shipping_addresses (
				    customer_id, recipient_name, postal_code, city, district,
				    address_line, phone, is_default)
				values (?, ?, ?, ?, ?, ?, ?, true)
				""", customerId, request.recipientName(), request.postalCode(),
				request.city(), request.district(), request.addressLine(), request.phone());
	}

	public void updateDefault(long id, MemberShippingAddressRequest request) {
		jdbc.update("""
				update customer_shipping_addresses
				set recipient_name = ?, postal_code = ?, city = ?, district = ?,
				    address_line = ?, phone = ?, updated_at = now()
				where id = ?
				""", request.recipientName(), request.postalCode(), request.city(),
				request.district(), request.addressLine(), request.phone(), id);
	}
}
