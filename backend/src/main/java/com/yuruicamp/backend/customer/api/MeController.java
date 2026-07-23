package com.yuruicamp.backend.customer.api;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.customer.application.MemberShippingAddressService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

/**
 * Skeleton probe: proves Firebase Bearer → CustomerPrincipal works.
 */
@RestController
@RequestMapping("/api/me")
@Tag(name = "Me")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class MeController {
	private final MemberShippingAddressService shippingAddressService;

	public MeController(MemberShippingAddressService shippingAddressService) {
		this.shippingAddressService = shippingAddressService;
	}

	@GetMapping
	@Operation(summary = "Current customer principal (requires prior /api/auth/firebase/session)")
	public ApiResponse<CustomerPrincipal> me(@AuthenticationPrincipal CustomerPrincipal principal) {
		return ApiResponse.ok(principal);
	}

	@GetMapping("/shipping-address")
	@Operation(summary = "Get the authenticated customer's default shipping address")
	public ApiResponse<MemberShippingAddressResponse> getShippingAddress(
			@AuthenticationPrincipal CustomerPrincipal principal) {
		return ApiResponse.ok(shippingAddressService.getDefault(principal.customerId()));
	}

	@PutMapping("/shipping-address")
	@Operation(summary = "Create or replace the authenticated customer's default shipping address")
	public ApiResponse<MemberShippingAddressResponse> saveShippingAddress(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody MemberShippingAddressRequest request) {
		return ApiResponse.ok(shippingAddressService.saveDefault(principal.customerId(), request));
	}
}
