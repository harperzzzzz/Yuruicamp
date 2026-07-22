package com.yuruicamp.backend.config;

import java.util.Arrays;
import java.util.List;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
public class WebConfig {

	@Bean
	CorsConfigurationSource corsConfigurationSource(YuruicampProperties properties) {
		// 用途：建立整個後端共用的 CORS 規則，讓允許的前端來源可以呼叫 API。
		// 核心重點：支援設定檔清單及逗號分隔環境變數；未設定時只開放本機 Vite 開發來源。
		List<String> origins = properties.getCors().getAllowedOrigins();
		if (origins == null || origins.isEmpty()) {
			origins = List.of("http://127.0.0.1:5173", "http://localhost:5173");
		}
		else if (origins.size() == 1 && origins.getFirst().contains(",")) {
			// 支援單一環境變數形式，例如 "http://a,http://b"。
			origins = Arrays.stream(origins.getFirst().split(","))
					.map(String::trim)
					.filter(s -> !s.isEmpty())
					.toList();
		}

		CorsConfiguration config = new CorsConfiguration();
		config.setAllowedOrigins(origins);
		config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
		config.setAllowedHeaders(List.of("*"));
		config.setAllowCredentials(true);
		config.setMaxAge(3600L);

		// 綠界的 OrderResultURL / ReturnURL 是綠界伺服器端網域自動送出的 callback，
		// 不是商城前端的 fetch/XHR 呼叫，因此不能套用上面商城限定的來源白名單，
		// 否則瀏覽器帶著綠界網域的 Origin 送出時會被 CorsFilter 直接擋下。
		CorsConfiguration ecpayCallbackConfig = new CorsConfiguration();
		ecpayCallbackConfig.setAllowedOriginPatterns(List.of("*"));
		ecpayCallbackConfig.setAllowedMethods(List.of("GET", "POST"));
		ecpayCallbackConfig.setAllowedHeaders(List.of("*"));
		ecpayCallbackConfig.setAllowCredentials(false);

		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		source.registerCorsConfiguration("/api/payments/ecpay/**", ecpayCallbackConfig);
		source.registerCorsConfiguration("/**", config);
		return source;
	}
}
