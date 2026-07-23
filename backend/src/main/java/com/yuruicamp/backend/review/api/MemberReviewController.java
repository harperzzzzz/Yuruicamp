package com.yuruicamp.backend.review.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.review.application.MemberReviewService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.http.ResponseEntity;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/me/reviews")
@Tag(name = "Member Reviews", description = "會員自己的已購商品評價")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class MemberReviewController {

	private final MemberReviewService service;

	public MemberReviewController(MemberReviewService service) {
		this.service = service;
	}

	@GetMapping
	@Operation(summary = "讀取目前會員的商品評價")
	public ApiResponse<List<MemberReviewResponse>> list(
			@AuthenticationPrincipal CustomerPrincipal principal) {
		return ApiResponse.ok(service.list(principal.customerId()));
	}

	@PostMapping
	@Operation(summary = "為本人已完成訂單的商品明細建立評價")
	public ApiResponse<MemberReviewResponse> create(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@Valid @RequestBody MemberReviewCreateRequest request) {
		return ApiResponse.ok(service.create(principal.customerId(), request));
	}

	@PostMapping(value = "/photos", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
	@Operation(summary = "上傳會員商品評論圖片")
	public ApiResponse<ReviewPhotoUploadResponse> uploadPhotos(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@RequestParam long orderItemId,
			@RequestPart("files") MultipartFile[] files) {
		return ApiResponse.ok(new ReviewPhotoUploadResponse(
				service.uploadPhotos(principal.customerId(), orderItemId, files)));
	}

	@PatchMapping("/{reviewId}")
	@Operation(summary = "修改目前會員自己的評論")
	public ApiResponse<MemberReviewResponse> update(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String reviewId,
			@Valid @RequestBody MemberReviewUpdateRequest request) {
		return ApiResponse.ok(service.update(principal.customerId(), reviewId, request));
	}

	@DeleteMapping("/{reviewId}")
	@Operation(summary = "刪除目前會員自己的評論")
	public ResponseEntity<Void> delete(
			@AuthenticationPrincipal CustomerPrincipal principal,
			@PathVariable String reviewId) {
		service.delete(principal.customerId(), reviewId);
		return ResponseEntity.noContent().build();
	}
}
