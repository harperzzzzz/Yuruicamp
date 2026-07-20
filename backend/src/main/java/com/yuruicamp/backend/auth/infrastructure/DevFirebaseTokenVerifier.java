package com.yuruicamp.backend.auth.infrastructure;

import java.util.Locale;
import java.util.Set;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Local development verifier. Token format:
 * {@code dev:<uid>:<email>:<provider>:<displayName>}
 * <p>
 * provider must be one of google / facebook / line.
 * Example: {@code dev:uid123:amy@example.com:google:Amy}
 */
@Component
@ConditionalOnProperty(prefix = "yuruicamp.firebase", name = "enabled", havingValue = "false", matchIfMissing = true)
public class DevFirebaseTokenVerifier implements FirebaseTokenVerifier {

	private static final Set<String> PROVIDERS = Set.of("google", "facebook", "line");

	@Override
	public VerifiedFirebaseToken verify(String idToken) {
		if (idToken == null || idToken.isBlank()) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED, "Missing Firebase ID token");
		}
		String token = idToken.trim();
		if (!token.startsWith("dev:")) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED,
					"Dev mode expects token starting with 'dev:'. Enable Firebase or use a stub token.");
		}
		String[] parts = token.split(":", 5);
		if (parts.length < 4) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED,
					"Invalid dev token. Expected dev:<uid>:<email>:<provider>[:displayName]");
		}
		String uid = parts[1].trim();
		String email = parts[2].trim().toLowerCase(Locale.ROOT);
		String provider = parts[3].trim().toLowerCase(Locale.ROOT);
		String name = parts.length >= 5 && !parts[4].isBlank() ? parts[4].trim() : email;
		if (uid.isEmpty() || email.isEmpty() || !PROVIDERS.contains(provider)) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid dev token fields");
		}
		return new VerifiedFirebaseToken(uid, email, name, provider, null);
	}
}
