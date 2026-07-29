package com.yuruicamp.backend.common.api;

import java.util.Map;

import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
@Tag(name = "Health")
public class HealthController {

	@GetMapping("/health")
	@Operation(summary = "Liveness / readiness probe for skeleton A")
	public ApiResponse<Map<String, String>> health() {
		return ApiResponse.ok(Map.of("status", "UP"));
	}
}
