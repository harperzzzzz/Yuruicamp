package com.yuruicamp.backend.customer.api;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

/**
 * 更新會員標籤池項目；未傳欄位保留原值。
 * Patch customer tag pool fields; omitted fields keep existing values.
 */
public record AdminCustomerTagUpdateRequest(
		@Size(max = 100) String name,
		@Size(max = 32) String color,
		@Min(0) Integer sortOrder,
		Boolean active) {
}
