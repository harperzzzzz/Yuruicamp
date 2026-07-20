package com.yuruicamp.backend.dto;

import java.math.BigDecimal;

public record CreateOrderResponse(
        String orderId,
        String orderNumber,
        BigDecimal totalAmount,
        String paymentStatus
) {
}
