package com.yuruicamp.backend.booking.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

// 一筆營位需求；quantity 是整段住宿期間每晚需要的營位數。
public record BookingAvailabilityZoneRequest(
		@NotBlank(message = "zoneId must not be blank") String zoneId,
		@NotNull(message = "quantity is required")
		@Positive(message = "quantity must be greater than zero") Integer quantity) {
}
