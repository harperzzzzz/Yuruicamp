package com.yuruicamp.backend.review.api;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.review.application.PublicProductReviewService;
import com.yuruicamp.backend.review.application.PublicProductReviewService.PagedProductReviews;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Validated
@RequestMapping("/api/products/{productId}/reviews")
@Tag(name = "Reviews", description = "Public verified-purchase product reviews")
public class PublicProductReviewController {

	private final PublicProductReviewService reviews;

	public PublicProductReviewController(PublicProductReviewService reviews) {
		this.reviews = reviews;
	}

	// 依商品取得可分頁、排序與篩選的公開評論。
	@GetMapping
	@Operation(summary = "取得商品公開評論與評分統計")
	public ApiResponse<ProductReviewsResponse> getReviews(
			@PathVariable String productId,
			@RequestParam(defaultValue = "0") @Min(0) int page,
			@RequestParam(defaultValue = "20") @Min(1) @Max(100) int size,
			@RequestParam(defaultValue = "latest") String sort,
			@RequestParam(required = false) @Min(1) @Max(5) Integer rating,
			@RequestParam(defaultValue = "false") boolean hasPhotos) {
		PagedProductReviews result = reviews.getReviews(productId, page, size, sort, rating, hasPhotos);
		return ApiResponse.ok(result.data(), result.meta());
	}
}
