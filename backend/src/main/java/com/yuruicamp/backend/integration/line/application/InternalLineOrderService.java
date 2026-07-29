package com.yuruicamp.backend.integration.line.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.config.YuruicampProperties;
import com.yuruicamp.backend.integration.line.api.InternalLineOrderResponse;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 供 n8n 呼叫：驗證 internal API key 後查詢已綁定會員的來源訂單狀態摘要。
@Service
public class InternalLineOrderService {

	private final OrderRepository orders;
	private final YuruicampProperties properties;

	public InternalLineOrderService(OrderRepository orders, YuruicampProperties properties) {
		this.orders = orders;
		this.properties = properties;
	}

	// 檢查 internal API key、必填參數，再回傳訂單歸屬本人時的狀態摘要。
	@Transactional(readOnly = true)
	public InternalLineOrderResponse getOrder(String apiKey, String orderId, String customerId) {
		validateApiKey(apiKey);
		if (orderId == null || orderId.isBlank() || customerId == null || customerId.isBlank()) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "orderId 與 customerId 不可為空");
		}

		Order order = orders.findForCustomer(orderId.trim(), customerId.trim())
				.orElseThrow(this::notFound);

		return toResponse(order);
	}

	private void validateApiKey(String apiKey) {
		String expected = properties.getLineIntegration().getInternalApiKey();

		if (expected == null || expected.isBlank() || !expected.equals(apiKey)) {
			throw new BusinessException(ErrorCode.FORBIDDEN, "Invalid internal API key");
		}
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "查無此訂單");
	}

	private InternalLineOrderResponse toResponse(Order order) {
		List<InternalLineOrderResponse.Item> items = order.getItems()
				.stream()
				.map(item -> new InternalLineOrderResponse.Item(item.getProductName(), item.getQuantity()))
				.toList();

		return new InternalLineOrderResponse(
				order.getId(),
				order.getDisplayNo(),
				order.getStatus().name(),
				order.getPaymentStatus().name(),
				order.getPaymentMethod().name().replace('_', '-'),
				money(order.getTotal()),
				order.getPlacedAt().toString(),
				items);
	}

	private String money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP)
				.toPlainString();
	}
}
