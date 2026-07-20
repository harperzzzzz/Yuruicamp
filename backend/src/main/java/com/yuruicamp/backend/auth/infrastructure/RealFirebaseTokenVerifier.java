package com.yuruicamp.backend.auth.infrastructure;

import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Locale;
import java.util.Map;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.auth.FirebaseAuthException;
import com.google.firebase.auth.FirebaseToken;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.config.YuruicampProperties;
import jakarta.annotation.PostConstruct;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * Verifies real Firebase ID Tokens via Firebase Admin SDK.
 */
@Component
@ConditionalOnProperty(prefix = "yuruicamp.firebase", name = "enabled", havingValue = "true")
public class RealFirebaseTokenVerifier implements FirebaseTokenVerifier {

	private static final Logger log = LoggerFactory.getLogger(RealFirebaseTokenVerifier.class);

	private final YuruicampProperties properties;

	public RealFirebaseTokenVerifier(YuruicampProperties properties) {
		this.properties = properties;
	}

	@PostConstruct
	void initFirebase() {
		if (!FirebaseApp.getApps().isEmpty()) {
			return;
		}
		String path = properties.getFirebase().getCredentialsPath();
		if (!StringUtils.hasText(path)) {
			throw new IllegalStateException(
					"yuruicamp.firebase.enabled=true requires yuruicamp.firebase.credentials-path");
		}
		try (InputStream in = new FileInputStream(path)) {
			FirebaseOptions options = FirebaseOptions.builder()
					.setCredentials(GoogleCredentials.fromStream(in))
					.build();
			FirebaseApp.initializeApp(options);
			log.info("Firebase Admin initialized from {}", path);
		}
		catch (IOException ex) {
			throw new IllegalStateException("Failed to load Firebase credentials: " + path, ex);
		}
	}

	@Override
	public VerifiedFirebaseToken verify(String idToken) {
		if (idToken == null || idToken.isBlank()) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED, "Missing Firebase ID token");
		}
		try {
			FirebaseToken decoded = FirebaseAuth.getInstance().verifyIdToken(idToken.trim());
			String email = decoded.getEmail();
			if (email == null || email.isBlank()) {
				throw new BusinessException(ErrorCode.UNAUTHORIZED, "Firebase token has no email");
			}
			String provider = mapProvider(decoded);
			String name = decoded.getName() != null && !decoded.getName().isBlank()
					? decoded.getName()
					: email;
			return new VerifiedFirebaseToken(
					decoded.getUid(),
					email.toLowerCase(Locale.ROOT),
					name,
					provider,
					decoded.getPicture());
		}
		catch (FirebaseAuthException ex) {
			throw new BusinessException(ErrorCode.UNAUTHORIZED, "Invalid Firebase ID token");
		}
	}

	private static String mapProvider(FirebaseToken decoded) {
		Object firebaseClaim = decoded.getClaims().get("firebase");
		if (firebaseClaim instanceof Map<?, ?> map) {
			Object signInProvider = map.get("sign_in_provider");
			if (signInProvider != null) {
				String raw = signInProvider.toString().toLowerCase(Locale.ROOT);
				if (raw.contains("google")) {
					return "google";
				}
				if (raw.contains("facebook")) {
					return "facebook";
				}
				if (raw.contains("line")) {
					return "line";
				}
			}
		}
		return "google";
	}
}
