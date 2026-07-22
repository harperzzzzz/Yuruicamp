package com.yuruicamp.backend.booking.api;

import java.time.Instant;
import java.time.LocalDate;

/**
 * 後台營區公休規則與建立者資訊的完整回應。
 */
public record AdminCampgroundClosureResponse(
		long id,
		String campgroundId,
		String campgroundName,
		String closureType,
		LocalDate startDate,
		LocalDate endDate,
		Integer weekday,
		LocalDate effectiveFrom,
		LocalDate effectiveTo,
		String reason,
		String createdBy,
		String createdByName,
		Instant createdAt,
		Instant updatedAt) {
}
