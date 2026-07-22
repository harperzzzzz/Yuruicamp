package com.yuruicamp.backend.inventory.api;

import java.util.List;

/**
 * 庫存異動表單可選的正式庫位與商品規格。
 */
public record AdminInventoryMovementLookupResponse(
		List<LocationOption> locations,
		List<VariantOption> variants) {

	public record LocationOption(
			String id,
			String code,
			String inventoryDomain,
			String type,
			String name) {
	}

	public record VariantOption(
			String inventoryDomain,
			String id,
			String sku,
			String productName,
			String specification) {
	}
}
