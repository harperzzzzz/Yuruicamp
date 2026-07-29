package com.yuruicamp.backend.inventory.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.AdminPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.inventory.application.AdminInventoryConversionService;
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

/**
 * ADM-W2-05：商城→租借跨領域庫存轉換（成對建立、過帳、作廢）。
 * RBAC 與 G-3 一致：讀 {@code movement.view}，寫 {@code movement.edit}。
 */
@RestController
@RequestMapping("/api/admin/inventory-conversions")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Inventory Conversions", description = "後台商城→租借跨領域庫存轉換草稿、過帳與作廢")
public class AdminInventoryConversionController {

	private final AdminInventoryConversionService service;

	public AdminInventoryConversionController(AdminInventoryConversionService service) {
		this.service = service;
	}

	// 查詢跨領域轉換分頁列表，包含草稿、已過帳與已作廢資料。
	@GetMapping
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "跨領域庫存轉換列表", description = "RBAC: movement.view")
	public ApiResponse<List<AdminInventoryConversionResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "100") int size,
			@RequestParam(defaultValue = "") String status) {
		var result = service.list(page, size, status);

		return ApiResponse.ok(result.data(), result.meta());
	}

	// 取得單筆跨領域轉換詳情（兩端異動單摘要＋規格與地點快照）。
	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('movement.view')")
	@Operation(summary = "跨領域庫存轉換詳情", description = "RBAC: movement.view")
	public ApiResponse<AdminInventoryConversionResponse> get(@PathVariable long id) {
		return ApiResponse.ok(service.get(id));
	}

	// 同一交易建立 store conversion_out ＋ rental conversion_in 草稿配對，不改庫存。
	@PostMapping
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "建立跨領域庫存轉換草稿", description = "RBAC: movement.edit；idempotencyKey 重送回放")
	public ApiResponse<AdminInventoryConversionResponse> createDraft(
			@AuthenticationPrincipal AdminPrincipal principal,
			@Valid @RequestBody AdminInventoryConversionCreateRequest request) {
		return ApiResponse.ok(service.createDraft(principal.adminUserId(), request));
	}

	// 悲觀鎖定轉換配對與兩張異動單後原子過帳：扣商城、加租借、兩邊一起標 posted。
	@PostMapping("/{id}/post")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "過帳跨領域庫存轉換", description = "RBAC: movement.edit；重複過帳冪等；庫存不足 409 並整筆 rollback")
	public ApiResponse<AdminInventoryConversionResponse> post(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable long id) {
		return ApiResponse.ok(service.post(id, principal.adminUserId()));
	}

	// 作廢尚未過帳的轉換草稿；兩張異動單一起作廢，作廢後不得再過帳。
	@PostMapping("/{id}/cancel")
	@PreAuthorize("hasAuthority('movement.edit')")
	@Operation(summary = "作廢跨領域庫存轉換", description = "RBAC: movement.edit")
	public ApiResponse<AdminInventoryConversionResponse> cancel(
			@AuthenticationPrincipal AdminPrincipal principal,
			@PathVariable long id) {
		return ApiResponse.ok(service.cancel(id, principal.adminUserId()));
	}
}
