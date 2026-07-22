package com.yuruicamp.backend.booking.api;

import io.swagger.v3.oas.annotations.media.Schema;

// 公開營位資料；金額一律使用固定兩位小數字串。
@Schema(description = "營區中的有效營位")
public record ZoneResponse(
		@Schema(example = "C002-Z-A") String id,
		@Schema(example = "草地營位") String type,
		int capacityPerSite,
		@Schema(example = "1200.00") String priceWeekday,
		@Schema(example = "1500.00") String priceHoliday,
		int totalSites,
		boolean active) {
}
