package com.yuruicamp.backend.branch.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 用途：建立門市主檔（客戶端提供 slug id，例如 branch-004）。
 * 核心重點：必填欄位對齊公開 Branch 契約；`active` 可省略，預設 `true`。
 * Create branch with client-provided slug id; `active` defaults to true when omitted.
 */
public record AdminBranchCreateRequest(
		@NotBlank @Size(max = 32) String id,
		@NotBlank @Size(max = 120) String name,
		@NotBlank @Size(max = 300) String address,
		@NotBlank @Size(max = 32) String phone,
		@DecimalMin("-90") @DecimalMax("90") BigDecimal latitude,
		@DecimalMin("-180") @DecimalMax("180") BigDecimal longitude,
		String mapQuery,
		@NotBlank @Size(max = 200) String businessHours,
		String imageUrl,
		Boolean active) {
}
