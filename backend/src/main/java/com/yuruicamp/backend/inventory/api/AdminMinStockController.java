package com.yuruicamp.backend.inventory.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.inventory.application.AdminMinStockService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 後台最低庫存閾值 API（W1-07）。只改閾值，不改 on_hand。
 * Admin min-stock endpoints: thresholds only, never on_hand.
 */
@RestController
@RequestMapping("/api/admin/min-stocks")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Min Stocks", description = "後台最低庫存閾值查詢與批次設定（不改實際庫存）")
public class AdminMinStockController {

	private final AdminMinStockService service;

	public AdminMinStockController(AdminMinStockService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "最低庫存列表", description = "RBAC: products.view；inventoryDomain 必填")
	public ApiResponse<List<AdminMinStockResponse>> list(
			@RequestParam String inventoryDomain,
			@RequestParam(required = false) String variantId,
			@RequestParam(required = false) String locationId,
			@RequestParam(required = false) String productId) {
		return ApiResponse.ok(service.list(inventoryDomain, variantId, locationId, productId));
	}

	@PutMapping
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(
			summary = "批次設定最低庫存",
			description = "RBAC: products.edit；upsert 閾值；不寫庫存異動、不改 on_hand")
	public ApiResponse<List<AdminMinStockResponse>> upsert(
			@Valid @RequestBody AdminMinStockUpsertRequest request) {
		return ApiResponse.ok(service.upsert(request));
	}
}
