package com.yuruicamp.backend.review.api;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;

/**
 * 會員建立已購商品評價的唯一可寫欄位。
 */
public record MemberReviewCreateRequest(
		@NotNull @Positive Long orderItemId,
		@Min(1) @Max(5) int rating,
		@Size(max = 1000) String comment,
		@Size(max = 5) List<String> photoUrls) {
}
