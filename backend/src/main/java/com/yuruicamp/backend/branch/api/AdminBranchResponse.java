package com.yuruicamp.backend.branch.api;

import java.math.BigDecimal;
import java.time.Instant;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * 用途：後台門市主檔回應（含 `active`；公開 API 的 {@link BranchResponse} 不含此欄位）。
 * 核心重點：後台列表／詳情皆回全部門市（含停用），只有公開 API 會過濾 active=true。
 * Admin branch response (includes `active`; public BranchResponse omits it).
 */
@Schema(description = "後台門市主檔資料")
public record AdminBranchResponse(
		@Schema(example = "branch-001") String id,
		@Schema(example = "Yuruicamp 台北旗艦店") String name,
		String address,
		String phone,
		BigDecimal latitude,
		BigDecimal longitude,
		String mapQuery,
		String businessHours,
		String imageUrl,
		boolean active,
		Instant createdAt,
		Instant updatedAt) {
}
