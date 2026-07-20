package com.yuruicamp.backend.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Stable machine-readable error codes for clients.
 * 給前端對照的錯誤代碼（與 HTTP status 分開）。
 */
public enum ErrorCode {

	VALIDATION_ERROR(HttpStatus.BAD_REQUEST),
	UNAUTHORIZED(HttpStatus.UNAUTHORIZED),
	FORBIDDEN(HttpStatus.FORBIDDEN),
	NOT_FOUND(HttpStatus.NOT_FOUND),
	ADMIN_INACTIVE(HttpStatus.FORBIDDEN),
	ADMIN_NOT_WHITELISTED(HttpStatus.FORBIDDEN),
	CUSTOMER_SUSPENDED(HttpStatus.FORBIDDEN),
	CONFLICT(HttpStatus.CONFLICT),
	INTERNAL_ERROR(HttpStatus.INTERNAL_SERVER_ERROR);

	private final HttpStatus status;

	ErrorCode(HttpStatus status) {
		this.status = status;
	}

	public HttpStatus getStatus() {
		return status;
	}

	public String code() {
		return name();
	}
}
