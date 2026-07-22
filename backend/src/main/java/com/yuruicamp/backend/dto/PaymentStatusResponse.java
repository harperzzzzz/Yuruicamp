package com.yuruicamp.backend.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

public record PaymentStatusResponse(
        String merchantTradeNo,
        String orderId,
        String transactionStatus,
        String paymentStatus,
        BigDecimal amount,
        OffsetDateTime paidAt
) {
}
