package com.yuruicamp.backend.common.api;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Unified success envelope for all REST responses.
 * 統一成功回應格式：{@code { success, data, meta? }}
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(boolean success, T data, Object meta) {

	public static <T> ApiResponse<T> ok(T data) {
		return new ApiResponse<>(true, data, null);
	}

	public static <T> ApiResponse<T> ok(T data, Object meta) {
		return new ApiResponse<>(true, data, meta);
	}
}
