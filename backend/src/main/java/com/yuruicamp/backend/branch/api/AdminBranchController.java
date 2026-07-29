package com.yuruicamp.backend.branch.api;

import java.util.List;

import com.yuruicamp.backend.branch.application.AdminBranchService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;

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
import org.springframework.web.bind.annotation.RestController;

/**
 * 用途：後台門市主檔 CRUD／啟停（ADM-W2-07）。
 * 核心重點：RBAC 沿用 `products.view`／`products.edit`（跟分類／品牌主檔共用門檻，不另立 permission code）。
 * Admin branches CRUD; RBAC reuses products.view/edit (documented decision, no new permission code).
 */
@RestController
@RequestMapping("/api/admin/branches")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Branches", description = "門市主檔查詢、建立、更新、啟停與安全刪除")
public class AdminBranchController {

	private final AdminBranchService service;

	public AdminBranchController(AdminBranchService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "門市列表", description = "RBAC: products.view；含停用門市，公開 API 只回 active")
	public ApiResponse<List<AdminBranchResponse>> list() {
		return ApiResponse.ok(service.list());
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "門市詳情", description = "RBAC: products.view")
	public ApiResponse<AdminBranchResponse> get(@PathVariable String id) {
		return ApiResponse.ok(service.get(id));
	}

	@PostMapping
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "建立門市", description = "RBAC: products.edit")
	public ApiResponse<AdminBranchResponse> create(@Valid @RequestBody AdminBranchCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "更新門市／啟停", description = "RBAC: products.edit；不可改 id；傳 active 即可啟停")
	public ApiResponse<AdminBranchResponse> update(
			@PathVariable String id,
			@Valid @RequestBody AdminBranchUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "刪除未引用門市", description = "RBAC: products.edit；有訂單取貨或庫位引用 → 409，改用 active=false")
	public ApiResponse<Void> delete(@PathVariable String id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
