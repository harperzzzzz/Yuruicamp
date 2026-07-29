package com.yuruicamp.backend.common.api;

import java.util.List;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * Unified error envelope: {@code { success:false, error:{ code, message, details? } }}.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiErrorBody(boolean success, ErrorPayload error) {

	public static ApiErrorBody of(String code, String message, List<ErrorDetail> details) {
		return new ApiErrorBody(false, new ErrorPayload(code, message, details));
	}

	public static ApiErrorBody of(String code, String message) {
		return of(code, message, null);
	}

	@JsonInclude(JsonInclude.Include.NON_NULL)
	public record ErrorPayload(String code, String message, List<ErrorDetail> details) {
	}

	public record ErrorDetail(String field, String reason) {
	}
}
