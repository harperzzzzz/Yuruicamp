package com.yuruicamp.backend.customer.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.customer.application.AdminCustomerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/customers")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Customers", description = "後台會員查詢、基本資料與停權管理")
public class AdminCustomerController {

	private final AdminCustomerService adminCustomerService;

	public AdminCustomerController(AdminCustomerService adminCustomerService) {
		this.adminCustomerService = adminCustomerService;
	}

	// 查詢後台會員分頁列表，支援關鍵字、狀態、等級、標籤與排序。
	@GetMapping
	@PreAuthorize("hasAuthority('customers.view')")
	@Operation(summary = "會員列表", description = "RBAC: customers.view")
	public ApiResponse<List<AdminCustomerListResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(defaultValue = "") String q,
			@RequestParam(defaultValue = "") String status,
			@RequestParam(defaultValue = "") String tier,
			@RequestParam(required = false) List<Long> tagId,
			@RequestParam(defaultValue = "registeredAt,desc") String sort) {
		var result = adminCustomerService.list(
				page, size, q, status, tier, tagId == null ? List.of() : tagId, sort);

		return ApiResponse.ok(result.data(), result.meta());
	}

	// 取得單一會員詳情與唯讀標籤、偏好、預設地址及交易筆數。
	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('customers.view')")
	@Operation(summary = "會員詳情", description = "RBAC: customers.view")
	public ApiResponse<AdminCustomerDetailResponse> get(@PathVariable String id) {
		return ApiResponse.ok(adminCustomerService.get(id));
	}

	// 更新會員姓名、電話、生日或點數，不允許修改登入身分欄位。
	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "更新會員基本資料", description = "RBAC: customers.edit")
	public ApiResponse<AdminCustomerDetailResponse> update(
			@PathVariable String id,
			@Valid @RequestBody AdminCustomerUpdateRequest request) {
		return ApiResponse.ok(adminCustomerService.update(id, request));
	}

	// 停權啟用中的會員，後續會員 API 會立即拒絕原 Token。
	@PostMapping("/{id}/suspend")
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "停權會員", description = "RBAC: customers.edit")
	public ApiResponse<AdminCustomerDetailResponse> suspend(@PathVariable String id) {
		return ApiResponse.ok(adminCustomerService.suspend(id));
	}

	// 恢復 suspended 會員，G-2a 不允許恢復 deleted 會員。
	@PostMapping("/{id}/reactivate")
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "恢復會員", description = "RBAC: customers.edit")
	public ApiResponse<AdminCustomerDetailResponse> reactivate(@PathVariable String id) {
		return ApiResponse.ok(adminCustomerService.reactivate(id));
	}
}
