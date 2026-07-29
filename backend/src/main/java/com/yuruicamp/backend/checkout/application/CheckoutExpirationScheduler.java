package com.yuruicamp.backend.checkout.application;

import java.time.Clock;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
// 條件啟動，讓「15 分鐘 Checkout 逾時釋放功能」預設開啟，可透過設定關閉
// havingValue 啟動Bean
// matchIfMissing ，沒有yuruicamp.checkout.expiration-enabled 也視為存在
@ConditionalOnProperty(name = "yuruicamp.checkout.expiration-enabled",
		havingValue = "true", matchIfMissing = true)
// 定期觸發 Checkout 逾時處理，交易規則由 Application Service 負責。
public class CheckoutExpirationScheduler {

	private final CheckoutExpirationService expirationService;

	private final Clock clock;

	// 注入可替換的時間來源，讓測試不必真的等待十五分鐘。
	public CheckoutExpirationScheduler(CheckoutExpirationService expirationService, Clock clock) {
		this.expirationService = expirationService;
		this.clock = clock;
	}

	// 依設定的間隔掃描已到期結帳，預設每分鐘執行一次。
	@Scheduled(fixedDelayString = "${yuruicamp.checkout.expiration-scan-ms:60000}")
	public void expireDueCheckouts() {
		expirationService.expireDueCheckouts(clock.instant());
	}
}
