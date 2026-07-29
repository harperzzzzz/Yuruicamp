package com.yuruicamp.backend.integration.line.infrastructure;

// 通知 n8n 建立綁定碼對照時的請求內容，欄位對齊 line_binding_codes。
public record LineBindingCodePayload(
		String bindCode,
		String customerId,
		String orderId,
		String expiresAt) {
}
