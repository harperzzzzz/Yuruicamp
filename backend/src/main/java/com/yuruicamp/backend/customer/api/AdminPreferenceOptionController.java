package com.yuruicamp.backend.customer.api;

import java.util.List;

import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.config.OpenApiConfig;
import com.yuruicamp.backend.customer.application.AdminCustomerService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 後台偏好選項 lookup（W1-05；本季不做 CRUD）。
 * Admin preference-option lookup only (no option CRUD this season).
 */
@RestController
@RequestMapping("/api/admin/preference-options")
@SecurityRequirement(name = OpenApiConfig.FIREBASE_BEARER)
@Tag(name = "Admin Preference Options", description = "後台偏好選項唯讀 lookup（供會員偏好勾選）")
public class AdminPreferenceOptionController {

	private final AdminCustomerService adminCustomerService;

	public AdminPreferenceOptionController(AdminCustomerService adminCustomerService) {
		this.adminCustomerService = adminCustomerService;
	}

	@GetMapping
	@PreAuthorize("hasAuthority('customers.view')")
	@Operation(summary = "偏好選項列表", description = "RBAC: customers.view；預設只回 active")
	public ApiResponse<List<AdminPreferenceOptionResponse>> list(
			@RequestParam(defaultValue = "false") boolean includeInactive) {
		return ApiResponse.ok(adminCustomerService.listPreferenceOptions(includeInactive));
	}
}
