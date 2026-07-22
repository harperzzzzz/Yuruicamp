package com.yuruicamp.backend.coupon.api;

import java.math.BigDecimal;
import java.time.Instant;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 更新優惠券可修改欄位，未提供的欄位保留資料庫原值。
 */
public record AdminCouponUpdateRequest(
		@Size(min = 1, max = 120) String name,
		@Pattern(regexp = "fixed|percent") String discountType,
		@DecimalMin(value = "0.01") BigDecimal discountValue,
		@DecimalMin(value = "0.00") BigDecimal minimumAmount,
		@Min(0) Integer issueQuantity,
		Instant validFrom,
		Instant validUntil,
		@Pattern(regexp = "active|disabled") String status,
		@Pattern(regexp = "promotion|birthday|firstPurchase") String category) {
}
