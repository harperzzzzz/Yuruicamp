package com.yuruicamp.backend.coupon.api;

import java.util.List;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.api.PageMeta;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.coupon.application.CouponService;

import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

@RestController
@Tag(name = "Coupon", description = "Coupon catalog and member claims")
// 提供公開券列表與會員領券 API。
public class CouponController {

	private final CouponService service;

	public CouponController(CouponService service) {
		this.service = service;
	}

	@GetMapping("/api/coupons")
	public ApiResponse<List<CouponResponse>> list() {
		List<CouponResponse> coupons = service.publicCoupons();

		return ApiResponse.ok(coupons, new PageMeta(0, coupons.size(), coupons.size(), coupons.isEmpty() ? 0 : 1));
	}

	// 取得目前登入會員自己的優惠券清單
	@GetMapping("/api/me/coupons")
	@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
	public ApiResponse<List<CouponClaimResponse>> mine(
			@AuthenticationPrincipal CustomerPrincipal principal) {
		List<CouponClaimResponse> claims = service.myCoupons(principal.customerId());

		return ApiResponse.ok(claims, new PageMeta(0, claims.size(), claims.size(), claims.isEmpty() ? 0 : 1));
	}

	// 領取 coupon
	@PostMapping("/api/me/coupons/claims")
	@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
	public ApiResponse<CouponClaimResponse> claim(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody CouponClaimRequest request) {
		return ApiResponse.ok(service.claim(principal.customerId(), request.couponId()));
	}
}
