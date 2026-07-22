package com.yuruicamp.backend.inventory.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.AdminPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.inventory.application.AdminInventoryMovementService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/inventory-movements")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Inventory Movements", description = "後台庫存異動草稿、明細、過帳與作廢")
public class AdminInventoryMovementController {

	private final AdminInventoryMovementService service;

	public AdminInventoryMovementController(AdminInventoryMovementService service) {
		this.service = service;
	}

	// 查詢庫存異動分頁列表，包含草稿、已過帳與已作廢資料。
	@GetMapping
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "庫存異動列表", description = "RBAC: movement.view")
	public ApiResponse<List<AdminInventoryMovementResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "100") int size,
			@RequestParam(defaultValue = "") String q,
			@RequestParam(defaultValue = "") String inventoryDomain,
			@RequestParam(defaultValue = "") String status,
			@RequestParam(defaultValue = "") String movementType,
			@RequestParam(defaultValue = "occurredAt,desc") String sort) {
		var result = service.list(
				page,
				size,
				q,
				inventoryDomain,
				status,
				movementType,
				sort);

		return ApiResponse.ok(result.data(), result.meta());
	}

	// 取得單一庫存異動與不可變的商品快照明細。
	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "庫存異動詳情", description = "RBAC: movement.view")
	public ApiResponse<AdminInventoryMovementResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	// 取得建立草稿時可使用的正式庫位與商品規格。
	@GetMapping("/lookups")
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "庫存異動選項", description = "RBAC: movement.view")
	public ApiResponse<AdminInventoryMovementLookupResponse> getLookups() {
		return ApiResponse.ok(service.getLookups());
	}

	// 建立 draft 表頭，這一步不會修改任何庫存數量。
	@PostMapping
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "建立庫存異動草稿", description = "RBAC: movement.edit")
	public ApiResponse<AdminInventoryMovementResponse> createDraft(
			@AuthenticationPrincipal AdminPrincipal principal,
			@Valid @RequestBody AdminInventoryMovementCreateRequest request) {
		return ApiResponse.ok(service.createDraft(principal.adminUserId(), request));
	}

	// 只允許對 draft 新增一筆商品規格明細。
	@PostMapping("/{id}/items")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "新增庫存異動明細", description = "RBAC: movement.edit")
	public ApiResponse<AdminInventoryMovementResponse> addItem(
			@PathVariable long id,
			@Valid @RequestBody AdminInventoryMovementItemRequest request) {
		return ApiResponse.ok(service.addItem(id, request));
	}

	// 悲觀鎖定異動單與庫存列後原子過帳，重複呼叫不會重複加減庫存。
	@PostMapping("/{id}/post")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "過帳庫存異動", description = "RBAC: movement.edit；重複過帳冪等")
	public ApiResponse<AdminInventoryMovementResponse> post(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable long id) {
		return ApiResponse.ok(service.post(id, principal.adminUserId()));
	}

	// 作廢尚未過帳的 draft，作廢後不得再新增明細或過帳。
	@PostMapping("/{id}/cancel")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "作廢庫存異動", description = "RBAC: movement.edit")
	public ApiResponse<AdminInventoryMovementResponse> cancel(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable long id) {
		return ApiResponse.ok(service.cancel(id, principal.adminUserId()));
	}
}
