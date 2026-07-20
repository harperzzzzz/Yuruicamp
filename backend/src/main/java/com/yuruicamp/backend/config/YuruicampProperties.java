package com.yuruicamp.backend.config;

import java.util.ArrayList;
import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Application-level settings bound from {@code yuruicamp.*} properties.
 * 專案設定：CORS、Firebase（只驗 ID Token，不自簽 JWT）。
 */
@ConfigurationProperties(prefix = "yuruicamp")
public class YuruicampProperties {

	private final Cors cors = new Cors();
	private final Firebase firebase = new Firebase();

	public Cors getCors() {
		return cors;
	}

	public Firebase getFirebase() {
		return firebase;
	}

	public static class Cors {
		/** Comma-separated origins are split in {@link WebConfig}. */
		private List<String> allowedOrigins = new ArrayList<>();

		public List<String> getAllowedOrigins() {
			return allowedOrigins;
		}

		public void setAllowedOrigins(List<String> allowedOrigins) {
			this.allowedOrigins = allowedOrigins;
		}
	}

	public static class Firebase {
		/** When false, use DevFirebaseTokenVerifier (tokens prefixed with {@code dev:}). */
		private boolean enabled = false;
		/** Absolute path to Firebase service-account JSON; empty when disabled. */
		private String credentialsPath = "";

		public boolean isEnabled() {
			return enabled;
		}

		public void setEnabled(boolean enabled) {
			this.enabled = enabled;
		}

		public String getCredentialsPath() {
			return credentialsPath;
		}

		public void setCredentialsPath(String credentialsPath) {
			this.credentialsPath = credentialsPath;
		}
	}
}
