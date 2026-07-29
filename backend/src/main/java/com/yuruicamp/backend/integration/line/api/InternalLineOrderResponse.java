package com.yuruicamp.backend.integration.line.api;

import java.util.List;

// n8n 客服查詢用的訂單摘要；只回傳狀態、金額與商品名稱，不含收件人、電話、Email 等個資欄位。
public record InternalLineOrderResponse(
		String id,
		String displayNo,
		String status,
		String paymentStatus,
		String paymentMethod,
		String total,
		String placedAt,
		List<Item> items) {

	public record Item(String productName, int quantity) {
	}
}
