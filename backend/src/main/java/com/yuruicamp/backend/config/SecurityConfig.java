package com.yuruicamp.backend.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.yuruicamp.backend.common.api.ApiErrorBody;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.common.security.FirebaseAuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;

@Configuration
@EnableWebSecurity
public class SecurityConfig {

	/**
	 * Disable the default generated in-memory user; auth is Firebase-only.
	 */
	@Bean
	UserDetailsService firebaseOnlyUserDetailsService() {
		return username -> {
			throw new UsernameNotFoundException("Password login disabled; use Firebase ID Token");
		};
	}

	@Bean
	SecurityFilterChain securityFilterChain(
			HttpSecurity http,
			FirebaseAuthenticationFilter firebaseAuthenticationFilter,
			ObjectMapper objectMapper) throws Exception {
		http
				.csrf(csrf -> csrf.ignoringRequestMatchers(
						request -> "POST".equals(request.getMethod())
								&& "/api/payments/ecpay/return".equals(request.getServletPath())))
				.cors(Customizer.withDefaults())
				.sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
				.authorizeHttpRequests(auth -> auth
						.requestMatchers(
								"/api/health",
								"/v3/api-docs/**",
								"/swagger-ui/**",
								"/swagger-ui.html")
						.permitAll()
						.requestMatchers(HttpMethod.POST, "/api/auth/firebase/session").permitAll()
						.requestMatchers(HttpMethod.POST, "/api/admin/auth/firebase/session").permitAll()
						.requestMatchers(HttpMethod.POST, "/api/payments/ecpay/return").permitAll()
						// 線 B：商品公開讀（Product API Contract v0.1）— 不必登入
						.requestMatchers(HttpMethod.GET, "/api/products", "/api/products/**").permitAll()
						// Skeleton A: other /api/admin/** require ROLE_ADMIN (whitelist resolved in filter)
						.requestMatchers("/api/admin/**").hasRole("ADMIN")
						// Other /api/** still require customer auth until more public GETs are added
						.requestMatchers("/api/**").hasRole("CUSTOMER")
						.anyRequest().authenticated())
				.exceptionHandling(ex -> ex
						.authenticationEntryPoint((request, response, authException) ->
								writeError(response, objectMapper, ErrorCode.UNAUTHORIZED,
										authException.getMessage() != null
												? authException.getMessage()
												: "Authentication required"))
						.accessDeniedHandler((request, response, accessDeniedException) ->
								writeError(response, objectMapper, ErrorCode.FORBIDDEN, "Access denied")))
				.addFilterBefore(firebaseAuthenticationFilter, UsernamePasswordAuthenticationFilter.class);
		return http.build();
	}

	private static void writeError(
			HttpServletResponse response,
			ObjectMapper objectMapper,
			ErrorCode code,
			String message) throws java.io.IOException {
		response.setStatus(code.getStatus().value());
		response.setContentType(MediaType.APPLICATION_JSON_VALUE);
		objectMapper.writeValue(response.getOutputStream(), ApiErrorBody.of(code.code(), message));
	}
}
