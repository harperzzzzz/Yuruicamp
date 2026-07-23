package com.yuruicamp.backend.review.api;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.review.application.AdminReviewService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 後台評論列表／詳情／硬刪（W1-06）。不做回覆與軟隱藏。
 * Admin reviews: list, detail, hard delete (no reply / soft-hide).
 */
@RestController
@RequestMapping("/api/admin/reviews")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Reviews", description = "後台評論查詢與硬刪")
public class AdminReviewController {

	private final AdminReviewService service;

	public AdminReviewController(AdminReviewService service) {
		this.service = service;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('reviews.view')")
	@Operation(summary = "評論列表", description = "RBAC: reviews.view")
	public ApiResponse<List<AdminReviewResponse>> list(
			@RequestParam(defaultValue = "0") int page,
			@RequestParam(defaultValue = "20") int size,
			@RequestParam(defaultValue = "") String q,
			@RequestParam(defaultValue = "") String productId,
			@RequestParam(required = false) Integer rating,
			@RequestParam(required = false) Instant createdFrom,
			@RequestParam(required = false) Instant createdTo,
			@RequestParam(defaultValue = "createdAt,desc") String sort) {
		var result = service.list(page, size, q, productId, rating, createdFrom, createdTo, sort);
		return ApiResponse.ok(result.data(), result.meta());
	}

	@GetMapping("/{id}")
	@PreAuthorize("hasAuthority('reviews.view')")
	@Operation(summary = "評論詳情", description = "RBAC: reviews.view")
	public ApiResponse<AdminReviewResponse> get(@PathVariable String id) {
		return ApiResponse.ok(service.get(id));
	}

	@DeleteMapping("/{id}")
	@PreAuthorize("hasAuthority('reviews.edit')")
	@Operation(summary = "硬刪評論", description = "RBAC: reviews.edit；photos CASCADE")
	public ApiResponse<Void> delete(@PathVariable String id) {
		service.delete(id);
		return ApiResponse.ok(null);
	}
}
