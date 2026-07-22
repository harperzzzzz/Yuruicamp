package com.yuruicamp.backend.catalog.api;

import java.util.List;

/**
 * 後台商品規格回應，包含停用規格與唯讀庫存摘要。
 */
public record AdminProductVariantResponse(
		String id,
		String sku,
		String color,
		String size,
		String specification,
		String price,
		String status,
		int onHandQuantity,
		int reservedQuantity,
		int availableQuantity,
		List<AdminProductStockLocationResponse> stockLocations) {
}
