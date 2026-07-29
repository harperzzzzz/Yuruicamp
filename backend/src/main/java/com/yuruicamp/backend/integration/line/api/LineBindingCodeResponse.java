package com.yuruicamp.backend.integration.line.api;

// 綁定碼回應：bindText 是前端唯一可顯示的提示文字，避免前端自行拼接綁定碼。
public record LineBindingCodeResponse(
		String bindCode,
		String bindText,
		String expiresAt,
		String lineUrl) {
}
