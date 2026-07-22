package com.yuruicamp.backend.booking.application;

import java.time.Clock;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

// E-6 定期觸發 Booking 逾時處理，交易與狀態重查由 Service 負責。
@Component
@ConditionalOnProperty(
		name = "yuruicamp.booking.expiration-enabled",
		havingValue = "true",
		matchIfMissing = true)
public class BookingExpirationScheduler {

	private final BookingLifecycleService lifecycleService;
	private final Clock clock;

	public BookingExpirationScheduler(BookingLifecycleService lifecycleService, Clock clock) {
		this.lifecycleService = lifecycleService;
		this.clock = clock;
	}

	// 預設每分鐘掃描一次已超過十五分鐘的 pending、unpaid Booking。
	@Scheduled(fixedDelayString = "${yuruicamp.booking.expiration-scan-ms:60000}")
	public void expireDueCheckouts() {
		lifecycleService.expireDueCheckouts(clock.instant());
	}
}
