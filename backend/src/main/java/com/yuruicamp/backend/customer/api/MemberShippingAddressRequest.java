package com.yuruicamp.backend.customer.api;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

// 會員本人配送地址寫入契約；customerId 一律由登入 principal 取得。
public record MemberShippingAddressRequest(
		@NotBlank @Size(max = 100) String recipientName,
		@NotBlank @Pattern(regexp = "(?:\\d{3}|\\d{5})") String postalCode,
		@NotBlank @Size(max = 50) String city,
		@NotBlank @Size(max = 50) String district,
		@NotBlank @Size(max = 300) String addressLine,
		@NotBlank @Pattern(regexp = "09\\d{8}") String phone,
		@NotBlank @Email @Size(max = 255) String email) {
}
