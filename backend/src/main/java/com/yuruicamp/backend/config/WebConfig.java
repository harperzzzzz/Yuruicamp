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
		List<String> origins = properties.getCors().getAllowedOrigins();
		if (origins == null || origins.isEmpty()) {
			origins = List.of("http://127.0.0.1:5173", "http://localhost:5173");
		}
		else if (origins.size() == 1 && origins.getFirst().contains(",")) {
			// Support single env var: "http://a,http://b"
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

		UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
		source.registerCorsConfiguration("/**", config);
		return source;
	}
}
