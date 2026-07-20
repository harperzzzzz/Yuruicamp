package com.yuruicamp.backend.checkout.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
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
// 在swagger UI上顯示此Controller的標題與描述
@Tag(
	name="Checkout",
	description="Draft order and 15-minute stock reservation"
)
// FIREBASE_BEARER 認證設定
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class CheckoutController {
	private final CheckoutService service; 
	public CheckoutController(CheckoutService service){
		this.service=service;
	}
	
	@PostMapping 
	public ApiResponse<CheckoutSessionResponse> create(@AuthenticationPrincipal CustomerPrincipal principal,@Valid @RequestBody CheckoutCreateRequest request){
		return ApiResponse.ok(service.create(principal.customerId(),request));
	}
	
	@PostMapping("/{orderId}/cancel") 
	public ApiResponse<CheckoutSessionResponse> cancel(@AuthenticationPrincipal CustomerPrincipal principal,@PathVariable String orderId){
		return ApiResponse.ok(service.cancel(principal.customerId(),orderId));
	}
}
