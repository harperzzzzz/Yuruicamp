package com.yuruicamp.backend.inventory.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.inventory.application.AdminInventoryLocationService;
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
 * 後台庫位主檔 CRUD／啟停（W2-06）。
 * Admin inventory locations CRUD.
 */
@RestController
@RequestMapping("/api/admin/inventory-locations")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Inventory Locations", description = "庫位主檔查詢、建立、啟停與安全刪除")
public class AdminInventoryLocationController {

	private final AdminInventoryLocationService service;

	public AdminInventoryLocationController(AdminInventoryLocationService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "庫位列表", description = "RBAC: movement.view；預設只回 active")
	public ApiResponse<List<AdminInventoryLocationResponse>> list(
			@RequestParam(defaultValue = "false") boolean includeInactive) {
		return ApiResponse.ok(service.list(includeInactive));
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "庫位詳情", description = "RBAC: movement.view")
	public ApiResponse<AdminInventoryLocationResponse> get(@PathVariable String id) {
		return ApiResponse.ok(service.get(id));
	}

	@PostMapping
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "建立庫位", description = "RBAC: movement.edit")
	public ApiResponse<AdminInventoryLocationResponse> create(
			@Valid @RequestBody AdminInventoryLocationCreateRequest request) {
		return ApiResponse.ok(service.create(request));
	}

	@PatchMapping("/{id}")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "更新庫位／啟停", description = "RBAC: movement.edit；有庫存禁停用")
	public ApiResponse<AdminInventoryLocationResponse> update(
			@PathVariable String id,
			@Valid @RequestBody AdminInventoryLocationUpdateRequest request) {
		return ApiResponse.ok(service.update(id, request));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "刪除未使用庫位", description = "RBAC: movement.edit")
	public ApiResponse<Void> delete(@PathVariable String id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
