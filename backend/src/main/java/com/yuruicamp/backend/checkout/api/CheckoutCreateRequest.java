package com.yuruicamp.backend.checkout.api;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
public record CheckoutCreateRequest(@NotEmpty List<@Valid Item> items, String paymentMethod, @Valid Shipping shipping, String idempotencyKey) {
	public record Item(@NotBlank String variantId,@Min(1) int quantity) {}
	public record Shipping(String recipientName,String phone,String address) {}
}
