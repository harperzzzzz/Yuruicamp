package com.yuruicamp.backend.catalog.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * 後台商品建立與更新輸入，只接受商品主檔、規格與圖片，不接受庫存或租借欄位。
 */
public record AdminProductUpsertRequest(
		@NotBlank @Size(max = 200) String name,
		@Size(max = 20000) String description,
		@NotNull Long categoryId,
		@Size(max = 32) String brandId,
		@NotBlank @Pattern(regexp = "active|inactive") String status,
		@Size(max = 20) List<@Valid AdminProductImageRequest> images,
		@NotEmpty @Size(max = 100) List<@Valid AdminProductVariantRequest> variants) {
}
