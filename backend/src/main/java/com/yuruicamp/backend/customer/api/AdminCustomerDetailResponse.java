package com.yuruicamp.backend.customer.api;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.customer.domain.CustomerStatus;

public record AdminCustomerDetailResponse(
		String id,
		String name,
		String phone,
		String email,
		LocalDate birthday,
		CustomerStatus status,
		Instant registeredAt,
		String tier,
		String tierName,
		String totalSpent,
		int points,
		boolean firstPurchaseUsed,
		String authProvider,
		boolean firebaseUidBound,
		String avatarUrl,
		Instant createdAt,
		Instant updatedAt,
		List<AdminCustomerTagResponse> tags,
		Map<String, List<String>> preferences,
		AdminCustomerAddressResponse defaultShippingAddress,
		long orderCount,
		long bookingCount) {
}
