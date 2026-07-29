package com.yuruicamp.backend.config;

import java.time.Clock;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

@Configuration
// 「開啟排程功能」，執行標有 @Scheduled 的方法
@EnableScheduling
// 啟用後端排程並提供統一的 UTC 時間來源。
public class SchedulingConfig {

	// 正式執行時使用系統 UTC 時間，測試可替換此 Bean。
	@Bean
	Clock checkoutClock() {
		return Clock.systemUTC();
	}
}
