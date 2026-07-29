package com.yuruicamp.backend.branch.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

/**
 * 用途：更新門市主檔（不可改 id）；未傳的欄位保留原值。
 * 核心重點：`active` 就是「啟停」開關——傳 `false` 即為停用，傳 `true` 即為復用；
 *          不需要另外開 activate／deactivate 端點。
 * Patch branch (id immutable); omitted fields keep existing values.
 * `active` doubles as the enable/disable toggle (no separate activate/deactivate endpoints needed).
 */
public record AdminBranchUpdateRequest(
		@Size(max = 120) String name,
		@Size(max = 300) String address,
		@Size(max = 32) String phone,
		@DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
		@DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
		String mapQuery,
		@Size(max = 200) String businessHours,
		String imageUrl,
		Boolean active) {
}
