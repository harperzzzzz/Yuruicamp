package com.yuruicamp.backend.catalog.infrastructure;

/**
 * 用途：承接商品規格可售量唯讀查詢結果。
 * 核心重點：只提供 Catalog 組裝需要的規格 ID 與可售數量。
 */
public interface VariantAvailabilityProjection {

	String getVariantId();

	Long getAvailableQuantity();
}
