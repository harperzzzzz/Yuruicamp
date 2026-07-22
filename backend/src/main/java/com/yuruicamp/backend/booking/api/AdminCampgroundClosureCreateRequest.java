package com.yuruicamp.backend.booking.api;

import java.time.LocalDate;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 建立營區指定日期或每週固定公休規則的輸入資料。
 */
public record AdminCampgroundClosureCreateRequest(
		@NotBlank @Size(max = 32) String campgroundId,
		@NotBlank @Pattern(regexp = "date_range|weekly") String closureType,
		LocalDate startDate,
		LocalDate endDate,
		@Min(0) @Max(6) Integer weekday,
		LocalDate effectiveFrom,
		LocalDate effectiveTo,
		@NotBlank @Size(max = 1000) String reason) {
}
