package com.yuruicamp.backend.auth.api;

import com.yuruicamp.backend.auth.application.AdminAuthService;
import com.yuruicamp.backend.common.api.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/auth")
@Tag(name = "Auth (Admin)")
public class AdminAuthController {

	private final AdminAuthService adminAuthService;

	public AdminAuthController(AdminAuthService adminAuthService) {
		this.adminAuthService = adminAuthService;
	}

	@PostMapping("/firebase/session")
	@Operation(
			summary = "Establish admin session from Firebase ID Token",
			description = """
					Email must already exist in `admin_users` (whitelist). Account must be active.
					First login binds `firebase_uid`. No backend JWT is issued.
					""")
	public ApiResponse<AdminSessionResponse> session(@Valid @RequestBody FirebaseSessionRequest request) {
		return ApiResponse.ok(adminAuthService.establishSession(request.idToken()));
	}
}
