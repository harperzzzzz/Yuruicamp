package com.yuruicamp.backend;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;

import org.springframework.boot.test.context.SpringBootTest;

/**
 * Full context load against Docker Postgres.
 * Enable with: {@code $env:RUN_BACKEND_IT="true"; $env:DB_PASSWORD="..."; ./mvnw test}
 */
@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
class BackendApplicationTests {

	@Test
	void contextLoads() {
	}
}
