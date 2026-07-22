package com.yuruicamp.backend.auth.api;

import java.time.Instant;

/**
 * Profile returned after customer Firebase session (no backend JWT).
 */
public record CustomerSessionResponse(
		String customerId,
		String email,
		String name,
		String authProvider,
		String firebaseUid,
		String status,
		Instant registeredAt,
		boolean created) {
}
