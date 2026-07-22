package com.yuruicamp.backend.catalog.api;

import java.math.BigDecimal;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 後台商品規格輸入；既有規格帶 ID，新規格不帶 ID 並由後端產生。
 */
public record AdminProductVariantRequest(
		@Size(max = 64) String id,
		@NotBlank @Size(max = 64) String sku,
		@Size(max = 100) String color,
		@Size(max = 100) String size,
		@NotBlank @Size(max = 200) String specification,
		@NotNull @DecimalMin(value = "0.00") BigDecimal price,
		@NotBlank @Pattern(regexp = "active|inactive") String status) {
}
