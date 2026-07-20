package com.yuruicamp.backend.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

public record CreateOrderItemRequest(
        @NotBlank String variantId,
        @Min(1) int quantity
) {
}
