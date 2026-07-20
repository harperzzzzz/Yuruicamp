package com.yuruicamp.backend.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;

public record CreateOrderRequest(
        @NotBlank String customerId,
        @NotBlank String buyerName,
        @Email @NotBlank String buyerEmail,
        @NotBlank String recipientName,
        @NotBlank String shippingAddress,
        @NotBlank String shippingPhone,
        String paymentMethod,
        @Valid @NotEmpty List<CreateOrderItemRequest> items
) {
}
