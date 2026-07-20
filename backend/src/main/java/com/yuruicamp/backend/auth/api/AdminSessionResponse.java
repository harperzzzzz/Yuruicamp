package com.yuruicamp.backend.auth.api;

/**
 * Profile returned after admin Firebase session (whitelist + active; no backend JWT).
 */
public record AdminSessionResponse(
		String adminUserId,
		String email,
		String name,
		String role,
		String firebaseUid,
		boolean firebaseUidBound) {
}
