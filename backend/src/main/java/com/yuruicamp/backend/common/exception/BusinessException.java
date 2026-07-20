package com.yuruicamp.backend.common.exception;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiErrorBody.ErrorDetail;

/**
 * Domain / use-case failure mapped to a stable {@link ErrorCode}.
 */
public class BusinessException extends RuntimeException {

	private final ErrorCode errorCode;
	private final List<ErrorDetail> details;

	public BusinessException(ErrorCode errorCode, String message) {
		this(errorCode, message, null);
	}

	public BusinessException(ErrorCode errorCode, String message, List<ErrorDetail> details) {
		super(message);
		this.errorCode = errorCode;
		this.details = details;
	}

	public ErrorCode getErrorCode() {
		return errorCode;
	}

	public List<ErrorDetail> getDetails() {
		return details;
	}
}
