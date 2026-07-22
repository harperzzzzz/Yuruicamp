package com.yuruicamp.backend.booking.api;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;
import io.swagger.v3.oas.annotations.media.Schema;

// 公開營區資料；列表省略 zones，詳情只回傳有效營位。
@JsonInclude(JsonInclude.Include.NON_NULL)
@Schema(description = "公開營區資料")
public record CampgroundResponse(
		@Schema(example = "C002") String id,
		@Schema(example = "雲海仙境露營區") String name,
		@Schema(example = "北部") String region,
		String description,
		boolean active,
		List<ZoneResponse> zones) {
}
