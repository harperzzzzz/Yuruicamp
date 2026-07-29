package com.yuruicamp.backend.coupon.api;

import java.math.BigDecimal;
import java.time.Instant;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 建立優惠券主檔的乾淨輸入，已領取數量與 ID 由後端決定。
 */
public record AdminCouponCreateRequest(
		@NotBlank @Size(max = 64) String code,
		@NotBlank @Size(max = 120) String name,
		@NotBlank @Pattern(regexp = "fixed|percent") String discountType,
		@NotNull @DecimalMin(value = "0.01") BigDecimal discountValue,
		@NotNull @DecimalMin(value = "0.00") BigDecimal minimumAmount,
		@Min(0) int issueQuantity,
		@NotNull Instant validFrom,
		@NotNull Instant validUntil,
		@NotBlank @Pattern(regexp = "active|disabled") String status,
		@NotBlank @Pattern(regexp = "promotion|birthday|firstPurchase") String category) {
}
