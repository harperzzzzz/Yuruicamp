package com.yuruicamp.backend.auth.infrastructure;

/**
 * Verifies a Firebase ID Token (or a local {@code dev:} stub token).
 */
public interface FirebaseTokenVerifier {

	VerifiedFirebaseToken verify(String idToken);
}
