package com.yuruicamp.backend.customer.api;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 後台覆寫會員預設收件地址請求（W1-04）。
 * Admin request to overwrite a customer's default shipping address.
 *
 * 全部欄位必填，對應 customer_shipping_addresses；不改訂單 snapshot。
 * All fields required; maps to customer_shipping_addresses only (never order snapshots).
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public record AdminCustomerDefaultShippingAddressRequest(
		@NotBlank @Size(max = 100) String recipientName,
		@NotBlank @Size(max = 10) String postalCode,
		@NotBlank @Size(max = 50) String city,
		@NotBlank @Size(max = 50) String district,
		@NotBlank @Size(max = 300) String addressLine,
		@NotBlank @Size(max = 32) @Pattern(regexp = "^09\\d{8}$") String phone) {
}
