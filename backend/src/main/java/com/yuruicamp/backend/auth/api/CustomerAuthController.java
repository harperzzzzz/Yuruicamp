package com.yuruicamp.backend.auth.api;

import com.yuruicamp.backend.auth.application.CustomerAuthService;
import com.yuruicamp.backend.common.api.ApiResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
@Tag(name = "Auth (Customer)")
public class CustomerAuthController {

	private final CustomerAuthService customerAuthService;

	public CustomerAuthController(CustomerAuthService customerAuthService) {
		this.customerAuthService = customerAuthService;
	}

	@PostMapping("/firebase/session")
	@Operation(
			summary = "Establish customer session from Firebase ID Token",
			description = """
					Verifies Firebase ID Token, upserts `customers` (binds firebase_uid),
					returns profile. Backend does **not** issue a JWT — keep using the Firebase ID Token
					as `Authorization: Bearer` on subsequent requests.
					""")
	public ApiResponse<CustomerSessionResponse> session(@Valid @RequestBody FirebaseSessionRequest request) {
		return ApiResponse.ok(customerAuthService.establishSession(request.idToken()));
	}
}
