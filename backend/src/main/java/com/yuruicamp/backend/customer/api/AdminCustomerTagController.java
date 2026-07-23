package com.yuruicamp.backend.customer.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.customer.application.AdminCustomerTagService;
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

/**
 * 後台會員標籤池 CRUD（W1-02）。指派／取消指派見 W1-03。
 * Admin customer tag pool endpoints (assign/unassign is W1-03).
 */
@RestController
@RequestMapping("/api/admin/customer-tags")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Customer Tags", description = "後台會員標籤池查詢、建立、更新與安全刪除")
public class AdminCustomerTagController {

	private final AdminCustomerTagService service;

	public AdminCustomerTagController(AdminCustomerTagService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('customers.view')")
	@Operation(summary = "標籤池列表", description = "RBAC: customers.view；預設只回 active")
	public ApiResponse<List<AdminCustomerTagPoolResponse>> list(
			@RequestParam(defaultValue = "false") boolean includeInactive) {
		return ApiResponse.ok(service.list(includeInactive));
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('customers.view')")
	@Operation(summary = "標籤池詳情", description = "RBAC: customers.view")
	public ApiResponse<AdminCustomerTagPoolResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	@PostMapping
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "建立標籤", description = "RBAC: customers.edit")
	public ApiResponse<AdminCustomerTagPoolResponse> create(
			@Valid @RequestBody AdminCustomerTagCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "更新標籤", description = "RBAC: customers.edit")
	public ApiResponse<AdminCustomerTagPoolResponse> update(
			@PathVariable long id,
			@Valid @RequestBody AdminCustomerTagUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('customers.edit')")
	@Operation(summary = "刪除未指派標籤", description = "RBAC: customers.edit；有指派時改停用")
	public ApiResponse<Void> delete(@PathVariable long id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
