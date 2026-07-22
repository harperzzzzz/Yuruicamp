package com.yuruicamp.backend.booking.api;

// 回傳單一營位在整段住宿期間的最低剩餘量。
public record BookingZoneAvailabilityResponse(
		String zoneId,
		int requested,
		int availableQuantity) {
}
