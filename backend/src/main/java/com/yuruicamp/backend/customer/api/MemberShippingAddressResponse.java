package com.yuruicamp.backend.customer.api;

// Email 取自 customers，配送地址表不重複保存會員信箱。
public record MemberShippingAddressResponse(
		long id,
		String recipientName,
		String postalCode,
		String city,
		String district,
		String addressLine,
		String phone,
		String email) {
}
