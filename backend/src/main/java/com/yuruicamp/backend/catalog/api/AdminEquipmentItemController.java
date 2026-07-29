package com.yuruicamp.backend.catalog.api;

import com.yuruicamp.backend.catalog.application.AdminEquipmentItemService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 依 {@code itemId} 維護裝備規格／標籤（W2-04）。獨立於
 * {@code /api/admin/products}／{@code /api/admin/rentals}，因為
 * {@code equipment_specifications}／{@code equipment_tags} 是 {@code equipment_items}
 * 的共用附屬表，商城商品與租借規格都是從同一張 {@code equipment_items} 延伸出來的
 * ——用 {@code itemId} 當唯一路徑，不分商城／租借，兩邊 UI 都呼叫同一組端點。
 *
 * <p>{@code itemId} 從商品／租借的詳情回應（{@code AdminProductResponse.itemId}／
 * {@code AdminRentalResponse.itemId}）取得。</p>
 */
@RestController
@RequestMapping("/api/admin/equipment-items")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Equipment Items", description = "依 itemId 維護裝備規格／標籤；商城與租借共用")
public class AdminEquipmentItemController {

	private final AdminEquipmentItemService service;

	public AdminEquipmentItemController(AdminEquipmentItemService service) {
		this.service = service;
	}

	// 查詢裝備目前的全部規格鍵值。
	@GetMapping("/{itemId}/specs")
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "裝備規格列表", description = "RBAC: products.view；W2-04")
	public ApiResponse<AdminEquipmentSpecsResponse> getSpecs(@PathVariable String itemId) {
		return ApiResponse.ok(service.getSpecs(itemId));
	}

	// 整組取代裝備規格：沒出現的既有 key 會被刪除（本表沒有 active 欄位可軟停用）。
	@PutMapping("/{itemId}/specs")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "同步裝備規格", description = "RBAC: products.edit；W2-04；整組取代，缺少的 key 會被刪除")
	public ApiResponse<AdminEquipmentSpecsResponse> replaceSpecs(
			@PathVariable String itemId,
			@Valid @RequestBody AdminEquipmentSpecsRequest request) {
		return ApiResponse.ok(service.replaceSpecs(itemId, request));
	}

	// 查詢裝備目前的全部查詢／特色標籤。
	@GetMapping("/{itemId}/tags")
	@PreAuthorize("hasAuthority('products.view')")
	@Operation(summary = "裝備標籤列表", description = "RBAC: products.view；W2-04")
	public ApiResponse<AdminEquipmentTagsResponse> getTags(@PathVariable String itemId) {
		return ApiResponse.ok(service.getTags(itemId));
	}

	// 整組取代裝備標籤：大小寫視為同一個標籤，重複自動去重。
	@PutMapping("/{itemId}/tags")
	@PreAuthorize("hasAuthority('products.edit')")
	@Operation(summary = "同步裝備標籤", description = "RBAC: products.edit；W2-04；整組取代，缺少的標籤會被刪除")
	public ApiResponse<AdminEquipmentTagsResponse> replaceTags(
			@PathVariable String itemId,
			@Valid @RequestBody AdminEquipmentTagsRequest request) {
		return ApiResponse.ok(service.replaceTags(itemId, request));
	}
}
