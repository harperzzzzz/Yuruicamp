package com.yuruicamp.backend.booking.api;

import java.util.List;

import io.swagger.v3.oas.annotations.media.Schema;

// 公開預約政策；occupyingStatuses 直接來自政策關聯表。
@Schema(description = "全站單例預約政策")
public record BookingPolicyResponse(
		int bookingWindowDays,
		int advanceDays,
		int maxNights,
		@Schema(example = "Asia/Taipei") String timezone,
		int dateBoundaryHour,
		int lowAvailabilityThreshold,
		List<String> occupyingStatuses) {
}
