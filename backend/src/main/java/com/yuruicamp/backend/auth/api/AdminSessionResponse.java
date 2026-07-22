package com.yuruicamp.backend.auth.api;

import java.util.Set;

/**
 * Profile returned after admin Firebase session (whitelist + active; no backend JWT).
 */
public record AdminSessionResponse(
		String adminUserId,
		String email,
		String name,
		String role,
		String firebaseUid,
		boolean firebaseUidBound,
		Set<String> effectivePermissions) {
}
