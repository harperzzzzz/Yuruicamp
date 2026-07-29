package com.yuruicamp.backend.customer.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 建立會員標籤池項目。
 * Create a customer tag in the admin tag pool.
 */
public record AdminCustomerTagCreateRequest(
		@NotBlank @Size(max = 100) String name,
		@NotBlank @Size(max = 32) String color,
		@Min(0) Integer sortOrder,
		Boolean active) {
}
