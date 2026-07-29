package com.yuruicamp.backend.customer.api;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.customer.domain.CustomerStatus;

public record AdminCustomerListResponse(
		String id,
		String name,
		String phone,
		String email,
		CustomerStatus status,
		Instant registeredAt,
		String tier,
		String tierName,
		String totalSpent,
		int points,
		List<AdminCustomerTagResponse> tags) {
}
