package com.yuruicamp.backend.customer.api;

import java.util.List;

import jakarta.validation.constraints.NotNull;

/**
 * 以完整 optionId 集合取代會員偏好（W1-05）。
 * Replace a customer's preference links with the full optionId set.
 */
public record AdminCustomerPreferencesReplaceRequest(
		@NotNull List<Long> optionIds) {
}
