package com.yuruicamp.backend.inventory.api;

/**
 * 庫存異動明細回應，SKU 與品名使用建立明細當下的快照。
 */
public record AdminInventoryMovementItemResponse(
		long id,
		String inventoryDomain,
		String variantId,
		String sku,
		String productName,
		int quantity) {
}
