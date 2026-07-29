package com.yuruicamp.backend.review.api;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record MemberReviewUpdateRequest(
		@Min(1) @Max(5) int rating,
		@Size(max = 1000) String comment,
		@Size(max = 5) List<String> photoUrls) {
}
