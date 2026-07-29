package com.yuruicamp.backend.customer.api;

import java.util.List;

import jakarta.validation.constraints.NotNull;

/**
 * 以完整 tagId 集合取代會員標籤指派（W1-03）。
 * Replace a customer's tag assignments with the full tagId set.
 */
public record AdminCustomerTagsReplaceRequest(
		@NotNull List<Long> tagIds) {
}
