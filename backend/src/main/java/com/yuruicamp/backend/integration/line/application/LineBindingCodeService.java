package com.yuruicamp.backend.integration.line.application;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.temporal.ChronoUnit;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.config.YuruicampProperties;
import com.yuruicamp.backend.integration.line.api.LineBindingCodeResponse;
import com.yuruicamp.backend.integration.line.infrastructure.LineBindingCodePayload;
import com.yuruicamp.backend.integration.line.infrastructure.LineBindingCodeWebhookClient;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// 從會員自己的訂單詳情產生一次性 LINE 綁定碼，並通知 n8n 建立對照。
@Service
public class LineBindingCodeService {

	private static final int BIND_CODE_DIGITS = 6;
	private static final int BIND_CODE_UPPER_BOUND = 1_000_000;
	private static final int EXPIRATION_MINUTES = 10;

	private final OrderRepository orders;
	private final YuruicampProperties properties;
	private final LineBindingCodeWebhookClient webhookClient;
	private final SecureRandom random = new SecureRandom();

	public LineBindingCodeService(
			OrderRepository orders,
			YuruicampProperties properties,
			LineBindingCodeWebhookClient webhookClient) {
		this.orders = orders;
		this.properties = properties;
		this.webhookClient = webhookClient;
	}

	// 確認訂單屬於本人，產生短效綁定碼並同步給 n8n。
	@Transactional(readOnly = true)
	public LineBindingCodeResponse createCode(String customerId, String orderId) {
		if (orderId == null || orderId.isBlank()) {
			throw notFound();
		}

		orders.findForCustomer(orderId.trim(), customerId)
				.orElseThrow(this::notFound);

		String bindCode = generateBindCode();
		Instant expiresAt = Instant.now()
				.plus(EXPIRATION_MINUTES, ChronoUnit.MINUTES);
		webhookClient.publish(new LineBindingCodePayload(
				bindCode,
				customerId,
				orderId.trim(),
				expiresAt.toString()));

		return new LineBindingCodeResponse(
				bindCode,
				"綁定 " + bindCode,
				expiresAt.toString(),
				properties.getLineIntegration().getOfficialAccountUrl());
	}

	// 產生固定 6 位數綁定碼，不足位數補零。
	private String generateBindCode() {
		int value = random.nextInt(BIND_CODE_UPPER_BOUND);

		return String.format("%0" + BIND_CODE_DIGITS + "d", value);
	}

	private BusinessException notFound() {
		return new BusinessException(ErrorCode.NOT_FOUND, "查無此訂單");
	}
}
