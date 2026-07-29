package com.yuruicamp.backend.integration.line.api;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.integration.line.application.InternalLineOrderService;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// n8n 專用內部 API：無會員 Bearer，改以 X-Internal-Api-Key 驗證身分。
@RestController
@RequestMapping("/api/internal/line/orders")
@Tag(name = "Internal LINE Orders", description = "n8n 專用：查詢已綁定會員的來源訂單狀態")
public class InternalLineOrderController {

	private final InternalLineOrderService service;

	public InternalLineOrderController(InternalLineOrderService service) {
		this.service = service;
	}

	// 依 orderId、customerId 查詢訂單摘要，供 n8n 組成 LINE 回覆內容。
	@GetMapping("/{orderId}")
	@Operation(summary = "n8n 查詢會員來源訂單狀態摘要")
	public ApiResponse<InternalLineOrderResponse> getOrder(
			@RequestHeader(value = "X-Internal-Api-Key", required = false) String apiKey,
			@PathVariable String orderId,
			@RequestParam String customerId) {
		return ApiResponse.ok(service.getOrder(apiKey, orderId, customerId));
	}
}
