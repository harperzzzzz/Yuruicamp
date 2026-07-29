package com.yuruicamp.backend.catalog.api;

import java.util.List;

import com.yuruicamp.backend.catalog.application.AdminCategoryService;
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
 * 後台分類主檔 CRUD（W2-01）。
 * Admin product categories CRUD.
 */
@RestController
@RequestMapping("/api/admin/categories")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Categories", description = "商品分類主檔查詢、建立、更新與安全刪除")
public class AdminCategoryController {

	private final AdminCategoryService service;

	public AdminCategoryController(AdminCategoryService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "分類列表", description = "RBAC: products.view")
	public ApiResponse<List<AdminCategoryResponse>> list() {
		return ApiResponse.ok(service.list());
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "分類詳情", description = "RBAC: products.view")
	public ApiResponse<AdminCategoryResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	@PostMapping
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "建立分類", description = "RBAC: products.edit")
	public ApiResponse<AdminCategoryResponse> create(@Valid @RequestBody AdminCategoryCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "更新分類", description = "RBAC: products.edit")
	public ApiResponse<AdminCategoryResponse> update(
			@PathVariable long id,
			@Valid @RequestBody AdminCategoryUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "刪除未引用分類", description = "RBAC: products.edit；有 equipment 引用 → 409")
	public ApiResponse<Void> delete(@PathVariable long id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
