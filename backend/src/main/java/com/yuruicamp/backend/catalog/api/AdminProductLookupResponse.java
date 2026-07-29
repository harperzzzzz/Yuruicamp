package com.yuruicamp.backend.catalog.api;

import java.util.List;

/**
 * 商品表單使用的分類與品牌選項，前端送出時使用 ID 而不是顯示名稱。
 */
public record AdminProductLookupResponse(
		List<CategoryOption> categories,
		List<BrandOption> brands) {

	public record CategoryOption(Long id, String name) {
	}

	public record BrandOption(String id, String name) {
	}
}
