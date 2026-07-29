package com.yuruicamp.backend.auth.infrastructure;

/**
 * Normalized claims after Firebase ID Token verification.
 * 驗證後的身分資訊（後端不再簽發自家 JWT）。
 */
public record VerifiedFirebaseToken(
		String uid,
		String email,
		String displayName,
		String authProvider,
		String pictureUrl) {
}
