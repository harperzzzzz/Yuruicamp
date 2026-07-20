package com.yuruicamp.backend.catalog.api;

import io.swagger.v3.oas.annotations.media.Schema;

/**
 * Contract v0.1 variant (SKU) — see docs/api/product-api-contract.md
 */
@Schema(description = "Product variant (SKU) per Product API Contract v0.1")
public record ProductVariantResponse(
		@Schema(example = "V001") String id,
		@Schema(example = "TENT-OLIVE") String sku,
		@Schema(nullable = true, example = "深橄欖綠") String color,
		@Schema(nullable = true) String size,
		@Schema(example = "深橄欖綠") String specification,
		@Schema(description = "Money as string with 2 decimal places", example = "3200.00") String price) {
}
