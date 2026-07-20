package com.yuruicamp.backend.customer.api;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import com.yuruicamp.backend.config.OpenApiConfig;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Skeleton probe: proves Firebase Bearer → CustomerPrincipal works.
 */
@RestController
@RequestMapping("/api/me")
@Tag(name = "Me")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
public class MeController {

	@GetMapping
	@Operation(summary = "Current customer principal (requires prior /api/auth/firebase/session)")
	public ApiResponse<CustomerPrincipal> me(@AuthenticationPrincipal CustomerPrincipal principal) {
		return ApiResponse.ok(principal);
	}
}
