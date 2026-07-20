package com.yuruicamp.backend.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * OpenAPI docs: Bearer token = Firebase ID Token (not a backend-issued JWT).
 */
@Configuration
public class OpenApiConfig {

	public static final String FIREBASE_BEARER = "firebaseBearer";

	@Bean
	OpenAPI yuruicampOpenApi() {
		return new OpenAPI()
				.info(new Info()
						.title("Yuruicamp API")
						.version("0.1.0")
						.description("""
								REST API for Yuruicamp.

								**Auth:** Send Firebase ID Token as `Authorization: Bearer <token>`.
								The backend verifies the token with Firebase Admin SDK and does **not** issue its own JWT.

								**Dev stub:** When `yuruicamp.firebase.enabled=false`, use tokens like
								`dev:<uid>:<email>:<provider>:<displayName>` (provider: google|facebook|line).
								"""))
				.components(new Components()
						.addSecuritySchemes(FIREBASE_BEARER, new SecurityScheme()
								.name(FIREBASE_BEARER)
								.type(SecurityScheme.Type.HTTP)
								.scheme("bearer")
								.bearerFormat("Firebase ID Token")
								.description("Firebase Auth ID Token")));
	}
}
