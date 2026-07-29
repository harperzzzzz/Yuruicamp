package com.yuruicamp.backend.customer.api;

public record AdminCustomerAddressResponse(
		Long id,
		String recipientName,
		String postalCode,
		String city,
		String district,
		String addressLine,
		String phone) {
}
