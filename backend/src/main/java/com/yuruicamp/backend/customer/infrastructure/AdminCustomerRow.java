package com.yuruicamp.backend.customer.infrastructure;

import java.math.BigDecimal;
import java.time.Instant;

import com.yuruicamp.backend.customer.domain.CustomerStatus;

public record AdminCustomerRow(
		String id,
		String name,
		String phone,
		String email,
		CustomerStatus status,
		Instant registeredAt,
		String tier,
		String tierName,
		BigDecimal totalSpent,
		int points) {
}
