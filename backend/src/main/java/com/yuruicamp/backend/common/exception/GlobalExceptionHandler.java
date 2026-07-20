package com.yuruicamp.backend.common.exception;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiErrorBody;
import com.yuruicamp.backend.common.api.ApiErrorBody.ErrorDetail;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice
public class GlobalExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	@ExceptionHandler(BusinessException.class)
	ResponseEntity<ApiErrorBody> handleBusiness(BusinessException ex) {
		ErrorCode code = ex.getErrorCode();
		return ResponseEntity.status(code.getStatus())
				.body(ApiErrorBody.of(code.code(), ex.getMessage(), ex.getDetails()));
	}

	@ExceptionHandler(MethodArgumentNotValidException.class)
	ResponseEntity<ApiErrorBody> handleValidation(MethodArgumentNotValidException ex) {
		List<ErrorDetail> details = ex.getBindingResult().getFieldErrors().stream()
				.map(this::toDetail)
				.toList();
		return ResponseEntity.badRequest()
				.body(ApiErrorBody.of(ErrorCode.VALIDATION_ERROR.code(), "Request validation failed", details));
	}

	@ExceptionHandler(ConstraintViolationException.class)
	ResponseEntity<ApiErrorBody> handleConstraintViolation(ConstraintViolationException ex) {
		List<ErrorDetail> details = ex.getConstraintViolations().stream()
				.map(violation -> new ErrorDetail(violation.getPropertyPath().toString(), violation.getMessage()))
				.toList();
		return ResponseEntity.badRequest()
				.body(ApiErrorBody.of(ErrorCode.VALIDATION_ERROR.code(), "Request validation failed", details));
	}

	@ExceptionHandler(AuthenticationException.class)
	ResponseEntity<ApiErrorBody> handleAuth(AuthenticationException ex) {
		return ResponseEntity.status(ErrorCode.UNAUTHORIZED.getStatus())
				.body(ApiErrorBody.of(ErrorCode.UNAUTHORIZED.code(), ex.getMessage()));
	}

	@ExceptionHandler(AccessDeniedException.class)
	ResponseEntity<ApiErrorBody> handleAccessDenied(AccessDeniedException ex) {
		return ResponseEntity.status(ErrorCode.FORBIDDEN.getStatus())
				.body(ApiErrorBody.of(ErrorCode.FORBIDDEN.code(), "Access denied"));
	}

	@ExceptionHandler(Exception.class)
	ResponseEntity<ApiErrorBody> handleUnexpected(Exception ex) {
		// Do not leak stack traces or secrets to clients / 不把堆疊與敏感資訊回給前端
		log.error("Unhandled exception", ex);
		return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.getStatus())
				.body(ApiErrorBody.of(ErrorCode.INTERNAL_ERROR.code(), "Unexpected server error"));
	}

	private ErrorDetail toDetail(FieldError fieldError) {
		return new ErrorDetail(fieldError.getField(), fieldError.getDefaultMessage());
	}
}
