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
	BOOKING_DATE_INVALID(HttpStatus.BAD_REQUEST),
	BOOKING_WINDOW_EXCEEDED(HttpStatus.BAD_REQUEST),
	ZONE_UNAVAILABLE(HttpStatus.CONFLICT),
	RENTAL_STOCK_INSUFFICIENT(HttpStatus.CONFLICT),
	IDEMPOTENCY_CONFLICT(HttpStatus.CONFLICT),
	STOCK_INSUFFICIENT(HttpStatus.CONFLICT),
	VARIANT_NOT_SELLABLE(HttpStatus.CONFLICT),
	CHECKOUT_EXPIRED(HttpStatus.CONFLICT),
	COUPON_SOLD_OUT(HttpStatus.CONFLICT),
	COUPON_ALREADY_CLAIMED(HttpStatus.CONFLICT),
	COUPON_NOT_ELIGIBLE(HttpStatus.CONFLICT),
	COUPON_NOT_APPLICABLE(HttpStatus.CONFLICT),
	COUPON_ALREADY_USED(HttpStatus.CONFLICT),
	REVIEW_ALREADY_EXISTS(HttpStatus.CONFLICT),
	REVIEW_ORDER_NOT_COMPLETED(HttpStatus.CONFLICT),
	REVIEW_ORDER_FORBIDDEN(HttpStatus.FORBIDDEN),
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
