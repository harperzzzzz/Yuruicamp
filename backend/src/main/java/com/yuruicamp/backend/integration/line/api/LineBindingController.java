package com.yuruicamp.backend.integration.line.api;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.integration.line.application.LineBindingCodeService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

// 會員從訂單詳情頁產生一次性 LINE 綁定碼，串接 n8n 訂單客服流程。
@RestController
@RequestMapping("/api/me/line-binding")
@Tag(name = "LINE Binding", description = "會員產生一次性 LINE 綁定碼，用於 n8n 訂單客服")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class LineBindingController {

	private final LineBindingCodeService service;

	public LineBindingController(LineBindingCodeService service) {
		this.service = service;
	}

	// 依登入會員與其擁有的訂單產生綁定碼，供使用者到 LINE 官方帳號輸入。
	@PostMapping("/code")
	@Operation(summary = "產生 LINE 綁定碼")
	public ApiResponse<LineBindingCodeResponse> createCode(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody LineBindingCodeRequest request) {
		return ApiResponse.ok(service.createCode(principal.customerId(), request.orderId()));
	}
}
