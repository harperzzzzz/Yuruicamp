package com.yuruicamp.backend.dto;

import java.math.BigDecimal;
import java.util.Map;

public record CreatePaymentResponse(
        Long paymentTransactionId,
        String orderId,
        String merchantTradeNo,
        BigDecimal amount,
        String currency,
        String status,
        String formAction,
        String formHtml,
        Map<String, String> formFields
) {
}
