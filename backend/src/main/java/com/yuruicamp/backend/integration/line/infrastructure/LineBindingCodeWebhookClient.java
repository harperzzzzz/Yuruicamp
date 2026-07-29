package com.yuruicamp.backend.integration.line.infrastructure;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.config.YuruicampProperties;

import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

// 呼叫 n8n Webhook，將一次性綁定碼與來源訂單資訊同步到 LINE 客服流程。
@Component
public class LineBindingCodeWebhookClient {

	private static final String INTERNAL_API_KEY_HEADER = "X-Internal-Api-Key";

	private final YuruicampProperties properties;
	private final RestClient restClient;

	public LineBindingCodeWebhookClient(YuruicampProperties properties) {
		this.properties = properties;
		this.restClient = RestClient.create();
	}

	// 將綁定碼 payload 送往 n8n；未設定 webhook 網址或呼叫失敗都視為業務錯誤。
	public void publish(LineBindingCodePayload payload) {
		String webhookUrl = properties.getLineIntegration()
				.getBindingCodeWebhookUrl();

		if (webhookUrl == null || webhookUrl.isBlank()) {
			throw new BusinessException(ErrorCode.CONFLICT, "LINE 綁定服務尚未設定");
		}

		try {
			restClient.post()
					.uri(webhookUrl)
					.header(INTERNAL_API_KEY_HEADER, properties.getLineIntegration().getInternalApiKey())
					.contentType(MediaType.APPLICATION_JSON)
					.body(payload)
					.retrieve()
					.toBodilessEntity();
		} catch (RestClientException ex) {
			throw new BusinessException(ErrorCode.INTERNAL_ERROR, "LINE 綁定服務目前無法連線");
		}
	}
}
