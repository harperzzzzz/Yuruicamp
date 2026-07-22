package com.yuruicamp.backend.booking.api;

import java.time.LocalDate;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 更新單一公休規則，未提供的欄位保留資料庫原值。
 */
public record AdminCampgroundClosureUpdateRequest(
		@Pattern(regexp = "date_range|weekly") String closureType,
		LocalDate startDate,
		LocalDate endDate,
		@Min(0) @Max(6) Integer weekday,
		LocalDate effectiveFrom,
		LocalDate effectiveTo,
		@Size(min = 1, max = 1000) String reason) {
}
