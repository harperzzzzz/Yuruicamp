package com.yuruicamp.backend.booking.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

// E-2 可用性查詢請求；日期保留字串，讓 Service 能回傳 Booking 專用日期錯誤碼。
public record BookingAvailabilityRequest(
		@NotBlank(message = "campgroundId must not be blank") String campgroundId,
		String checkIn,
		String checkOut,
		@NotEmpty(message = "zones must not be empty") List<@Valid BookingAvailabilityZoneRequest> zones) {
}
