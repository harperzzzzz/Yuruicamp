package com.yuruicamp.backend.booking.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

// E-3 建立預約 Checkout 的輸入；金額一律不從前端接收。
public record BookingCheckoutCreateRequest(
		@NotBlank @Size(max = 32) String campgroundId,
		String checkIn,
		String checkOut,
		@NotNull @Positive Integer guestCount,
		@NotEmpty List<@NotNull @Valid Zone> zones,
		List<@NotNull @Valid Rental> rentals,
		Long couponClaimId,
		@NotBlank @Size(max = 32) String paymentMethod,
		@NotBlank @Size(max = 128) String idempotencyKey) {

	// 每一筆代表整段住宿期間每晚需要的營位數。
	public record Zone(
			@NotBlank @Size(max = 32) String zoneId,
			@NotNull @Positive Integer quantity) {
	}

	// 每筆租借同時帶 listing 與 variant，後端會驗證兩者及營區關係。
	public record Rental(
			@NotBlank @Size(max = 64) String rentalListingId,
			@NotBlank @Size(max = 64) String rentalSkuVariantId,
			@NotNull @Positive Integer quantity) {
	}
}
