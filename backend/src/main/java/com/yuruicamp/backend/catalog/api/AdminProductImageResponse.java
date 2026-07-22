package com.yuruicamp.backend.catalog.api;

/**
 * 後台商品圖片回應，sortOrder 為零的圖片是主圖。
 */
public record AdminProductImageResponse(
		int sortOrder,
		String url,
		String altText) {
}
