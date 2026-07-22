package com.yuruicamp.backend.checkout.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.yuruicamp.backend.checkout.application.CheckoutService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;

import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/checkout/sessions")
// 在 Swagger UI 顯示 Checkout API。
@Tag(
		name = "Checkout",
		description = "Draft order and 15-minute stock reservation"
)
// Checkout API 必須使用 Firebase Bearer Token。
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class CheckoutController {

	private final CheckoutService service;

	// 準備 Checkout API 需要使用的服務。
	public CheckoutController(CheckoutService service) {
		this.service = service;
	}

	// 建立待付款 Checkout 並保留庫存。
	@PostMapping
	public ApiResponse<CheckoutSessionResponse> create(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody CheckoutCreateRequest request) {
		return ApiResponse.ok(service.create(principal.customerId(), request));
	}

	// 讀取會員自己的 Checkout 最新快照。
	@GetMapping("/{orderId}")
	public ApiResponse<CheckoutSessionResponse> get(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId) {
		return ApiResponse.ok(service.get(principal.customerId(), orderId));
	}

	// 更新會員自己的 Checkout 收件資料與付款方式。
	@PatchMapping("/{orderId}")
	public ApiResponse<CheckoutSessionResponse> update(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId,
			@Valid @RequestBody CheckoutUpdateRequest request) {
		return ApiResponse.ok(service.update(principal.customerId(), orderId, request));
	}

	// 取消會員自己的未付款 Checkout 並釋放庫存。
	@PostMapping("/{orderId}/cancel")
	public ApiResponse<CheckoutSessionResponse> cancel(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId) {
		return ApiResponse.ok(service.cancel(principal.customerId(), orderId));
	}

	// 確認貨到付款訂單成立，付款狀態仍為 unpaid。
	@PostMapping("/{orderId}/confirm-cod")
	public ApiResponse<CheckoutSessionResponse> confirmCod(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId) {
		return ApiResponse.ok(service.confirmCod(principal.customerId(), orderId));
	}
}
