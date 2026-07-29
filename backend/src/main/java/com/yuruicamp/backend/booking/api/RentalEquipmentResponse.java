package com.yuruicamp.backend.booking.api;

import io.swagger.v3.oas.annotations.media.Schema;

// 公開租借 listing；不輸出前端 Mock stock，庫存真相留在 PostgreSQL。
@Schema(description = "營區可租借的有效裝備")
public record RentalEquipmentResponse(
		@Schema(example = "RL-DEV-C002-001") String id,
		@Schema(example = "RSV-DEV-001") String rentalSkuVariantId,
		@Schema(example = "C002") String campgroundId,
		@Schema(example = "露營折疊椅租借") String name,
		@Schema(example = "180.00") String pricePerDayWeekday,
		@Schema(example = "220.00") String pricePerDayHoliday,
		boolean active) {
}
