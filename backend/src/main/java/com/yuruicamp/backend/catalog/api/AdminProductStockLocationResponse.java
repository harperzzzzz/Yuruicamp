package com.yuruicamp.backend.catalog.api;

/**
 * 商品規格在單一商城庫位的唯讀庫存，不提供 G-2c 寫入。
 */
public record AdminProductStockLocationResponse(
		String locationId,
		String locationCode,
		String locationType,
		String branchId,
		String locationName,
		int onHandQuantity,
		int reservedQuantity,
		int availableQuantity) {
}
