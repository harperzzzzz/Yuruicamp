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
import org.springframework.http.converter.HttpMessageNotReadableException;

@RestControllerAdvice
// 將後端錯誤轉成統一的 API 回應。
public class GlobalExceptionHandler {

	private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

	// 回傳系統已定義的業務錯誤。
	@ExceptionHandler(BusinessException.class)
	ResponseEntity<ApiErrorBody> handleBusiness(BusinessException ex) {
		ErrorCode code = ex.getErrorCode();
		return ResponseEntity.status(code.getStatus())
				.body(ApiErrorBody.of(code.code(), ex.getMessage(), ex.getDetails()));
	}

	// 回傳請求欄位驗證錯誤。
	@ExceptionHandler(MethodArgumentNotValidException.class)
	ResponseEntity<ApiErrorBody> handleValidation(MethodArgumentNotValidException ex) {
		List<ErrorDetail> details = ex.getBindingResult().getFieldErrors().stream()
				.map(this::toDetail)
				.toList();
		return ResponseEntity.badRequest()
				.body(ApiErrorBody.of(ErrorCode.VALIDATION_ERROR.code(), "Request validation failed", details));
	}

	// 回傳網址參數或方法參數的驗證錯誤。
	@ExceptionHandler(ConstraintViolationException.class)
	ResponseEntity<ApiErrorBody> handleConstraintViolation(ConstraintViolationException ex) {
		List<ErrorDetail> details = ex.getConstraintViolations().stream()
				.map(violation -> new ErrorDetail(violation.getPropertyPath().toString(), violation.getMessage()))
				.toList();
		return ResponseEntity.badRequest()
				.body(ApiErrorBody.of(ErrorCode.VALIDATION_ERROR.code(), "Request validation failed", details));
	}

	// 空白或格式錯誤的請求內容統一回傳 400。
	@ExceptionHandler(HttpMessageNotReadableException.class)
	ResponseEntity<ApiErrorBody> handleUnreadableBody(HttpMessageNotReadableException ex) {
		return ResponseEntity.badRequest()
				.body(ApiErrorBody.of(ErrorCode.VALIDATION_ERROR.code(), "Request body is missing or invalid"));
	}

	// 回傳登入驗證錯誤。
	@ExceptionHandler(AuthenticationException.class)
	ResponseEntity<ApiErrorBody> handleAuth(AuthenticationException ex) {
		return ResponseEntity.status(ErrorCode.UNAUTHORIZED.getStatus())
				.body(ApiErrorBody.of(ErrorCode.UNAUTHORIZED.code(), ex.getMessage()));
	}

	// 回傳沒有操作權限的錯誤。
	@ExceptionHandler(AccessDeniedException.class)
	ResponseEntity<ApiErrorBody> handleAccessDenied(AccessDeniedException ex) {
		return ResponseEntity.status(ErrorCode.FORBIDDEN.getStatus())
				.body(ApiErrorBody.of(ErrorCode.FORBIDDEN.code(), "Access denied"));
	}

	// 未預期錯誤統一回傳 500。
	@ExceptionHandler(Exception.class)
	ResponseEntity<ApiErrorBody> handleUnexpected(Exception ex) {
		// 不將錯誤細節與敏感資料回傳給前端。
		log.error("Unhandled exception", ex);
		return ResponseEntity.status(ErrorCode.INTERNAL_ERROR.getStatus())
				.body(ApiErrorBody.of(ErrorCode.INTERNAL_ERROR.code(), "Unexpected server error"));
	}

	// 將欄位錯誤轉成 API 錯誤明細。
	private ErrorDetail toDetail(FieldError fieldError) {
		return new ErrorDetail(fieldError.getField(), fieldError.getDefaultMessage());
	}
}
