package com.yuruicamp.backend.branch.api;

import java.math.BigDecimal;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 用途：定義公開門市 API 的固定欄位。
 * 核心重點：資料庫 snake_case 欄位在 JSON 統一輸出 camelCase。
 */
@Schema(description = "公開門市資料")
public record BranchResponse(
		@Schema(example = "branch-001") String id,
		@Schema(example = "Yuruicamp 台北旗艦店") String name,
		String address,
		String phone,
		BigDecimal latitude,
		BigDecimal longitude,
		String mapQuery,
		String businessHours,
		String imageUrl) {
}
