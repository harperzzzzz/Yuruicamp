package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 後台商品圖片輸入，陣列順序就是圖片顯示順序，第一張為主圖。
 */
public record AdminProductImageRequest(
		@NotBlank @Size(max = 2000) String url,
		@Size(max = 200) String altText) {
}
