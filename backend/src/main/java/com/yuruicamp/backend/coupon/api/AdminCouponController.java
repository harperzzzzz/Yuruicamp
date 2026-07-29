package com.yuruicamp.backend.coupon.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.coupon.application.AdminCouponService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/coupons")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Coupons", description = "後台優惠券查詢、建立、更新與安全刪除")
public class AdminCouponController {

	private final AdminCouponService service;

	public AdminCouponController(AdminCouponService service) {
		this.service = service;
	}

	// 查詢優惠券分頁列表，支援關鍵字、狀態、類別與白名單排序。
	@GetMapping
	@PreAuthorize("hasAuthority('discounts.view')")
	@Operation(summary = "優惠券列表", description = "RBAC: discounts.view")
	public ApiResponse<List<AdminCouponResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "100") int size,
			@RequestParam(defaultValue = "") String q,
			@RequestParam(defaultValue = "") String status,
			@RequestParam(defaultValue = "") String category,
			@RequestParam(defaultValue = "createdAt,desc") String sort) {
		var result = service.list(page, size, q, status, category, sort);

		return ApiResponse.ok(result.data(), result.meta());
	}

	// 取得單一優惠券主檔與目前領取數量。
	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('discounts.view')")
	@Operation(summary = "優惠券詳情", description = "RBAC: discounts.view")
	public ApiResponse<AdminCouponResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	// 建立優惠券，優惠碼會由後端轉成大寫並驗證唯一性。
	@PostMapping
	@PreAuthorize("hasAuthority('discounts.edit')")
	@Operation(summary = "建立優惠券", description = "RBAC: discounts.edit")
	public ApiResponse<AdminCouponResponse> create(
			@Valid @RequestBody AdminCouponCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	// 更新優惠券期間、折扣、發行量、狀態或類別，優惠碼不可修改。
	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('discounts.edit')")
	@Operation(summary = "更新優惠券", description = "RBAC: discounts.edit")
	public ApiResponse<AdminCouponResponse> update(
			@PathVariable long id,
			@Valid @RequestBody AdminCouponUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	// 只刪除從未被領取的優惠券，已有領券歷程時必須改為停用。
	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('discounts.edit')")
	@Operation(summary = "刪除未領取優惠券", description = "RBAC: discounts.edit")
	public ApiResponse<Void> delete(@PathVariable long id) {
		service.delete(id);

		return ApiResponse.ok(null);
	}
}
