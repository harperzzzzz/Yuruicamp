package com.yuruicamp.backend.auth.api;

import jakarta.validation.constraints.NotBlank;

/**
 * Body for Firebase session exchange. Client may also send the same token as Bearer.
 */
public record FirebaseSessionRequest(
		@NotBlank(message = "idToken is required") String idToken) {
}
