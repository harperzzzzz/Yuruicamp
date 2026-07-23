package com.yuruicamp.backend.inventory.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 建立庫位主檔。
 * Create inventory location.
 */
public record AdminInventoryLocationCreateRequest(
		@NotBlank @Size(max = 32) String id,
		@NotBlank @Size(max = 32) String code,
		@NotBlank @Pattern(regexp = "store|rental") String inventoryDomain,
		@NotBlank @Size(max = 32) String type,
		@Size(max = 32) String branchId,
		@NotBlank @Size(max = 120) String name,
		Boolean active) {
}
