package com.yuruicamp.backend.booking.api;

import java.time.LocalDate;

import io.swagger.v3.oas.annotations.media.Schema;

// 公開營區關閉規則；日期區間與每週規則共用同一個 DTO。
@Schema(description = "營區公休或關閉規則")
public record CampgroundClosureResponse(
		long id,
		@Schema(example = "C002") String campgroundId,
		@Schema(example = "date_range") String closureType,
		LocalDate startDate,
		LocalDate endDate,
		Integer weekday,
		LocalDate effectiveFrom,
		LocalDate effectiveTo,
		String reason) {
}
