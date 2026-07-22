package com.yuruicamp.backend.checkout.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
import com.yuruicamp.backend.dto.CreatePaymentRequest;
import com.yuruicamp.backend.dto.CreatePaymentResponse;
import com.yuruicamp.backend.service.PaymentService;

import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@RequestMapping("/api/checkout/sessions")
@Tag(
		name = "Checkout",
		description = "Draft order and 15-minute stock reservation"
)
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class CheckoutController {

	private final CheckoutService service;
	private final PaymentService paymentService;

	public CheckoutController(CheckoutService service, PaymentService paymentService) {
		this.service = service;
		this.paymentService = paymentService;
	}

	@PostMapping
	public ApiResponse<CheckoutSessionResponse> create(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody CheckoutCreateRequest request) {
		return ApiResponse.ok(service.create(principal.customerId(), request));
	}

	@PatchMapping("/{orderId}")
	public ApiResponse<CheckoutSessionResponse> update(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId,
			@Valid @RequestBody CheckoutUpdateRequest request) {
		return ApiResponse.ok(service.update(principal.customerId(), orderId, request));
	}

	@PostMapping("/{orderId}/cancel")
	public ApiResponse<CheckoutSessionResponse> cancel(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String orderId) {
		return ApiResponse.ok(service.cancel(principal.customerId(), orderId));
	}

	@PostMapping("/{orderId}/ecpay")
	public ApiResponse<CreatePaymentResponse> createEcpayForm(@PathVariable String orderId) {
		return ApiResponse.ok(paymentService.createPayment(new CreatePaymentRequest(orderId)));
	}
}
