package com.yuruicamp.backend.catalog.api;

import java.util.List;

import com.yuruicamp.backend.catalog.application.AdminBrandService;
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
 * 後台品牌主檔 CRUD（W2-02）。
 * Admin brands CRUD.
 */
@RestController
@RequestMapping("/api/admin/brands")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Brands", description = "品牌主檔查詢、建立、更新與安全刪除")
public class AdminBrandController {

	private final AdminBrandService service;

	public AdminBrandController(AdminBrandService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "品牌列表", description = "RBAC: products.view")
	public ApiResponse<List<AdminBrandResponse>> list() {
		return ApiResponse.ok(service.list());
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "品牌詳情", description = "RBAC: products.view")
	public ApiResponse<AdminBrandResponse> get(@PathVariable String id) {
		return ApiResponse.ok(service.get(id));
	}

	@PostMapping
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "建立品牌", description = "RBAC: products.edit")
	public ApiResponse<AdminBrandResponse> create(@Valid @RequestBody AdminBrandCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "更新品牌", description = "RBAC: products.edit；不可改 id")
	public ApiResponse<AdminBrandResponse> update(
			@PathVariable String id,
			@Valid @RequestBody AdminBrandUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "刪除未引用品牌", description = "RBAC: products.edit；有 equipment 引用 → 409")
	public ApiResponse<Void> delete(@PathVariable String id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
