package com.yuruicamp.backend.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.yuruicamp.backend.config.EcpayProperties;
import com.yuruicamp.backend.entity.PaymentTransaction;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.domain.PaymentMethod;
import com.yuruicamp.backend.order.domain.PaymentStatus;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;
import com.yuruicamp.backend.payment.EcpayCheckMacValue;
import com.yuruicamp.backend.repository.PaymentTransactionRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.web.server.ResponseStatusException;

class PaymentServiceTest {

    private static final String MERCHANT_ID = "3002607";
    private static final String HASH_KEY = "pwFHCqoQZGmho4w6";
    private static final String HASH_IV = "EkRm7iFT261dpevs";
    private static final String MERCHANT_TRADE_NO = "YRC260721120000000";
    private static final String GATEWAY_TRADE_NO = "2507211234567890";

    private PaymentTransactionRepository paymentTransactions;
    private EcpayCheckMacValue checkMacValue;
    private PaymentService service;

    @BeforeEach
    void setUp() {
        OrderRepository orders = mock(OrderRepository.class);
        paymentTransactions = mock(PaymentTransactionRepository.class);
        checkMacValue = new EcpayCheckMacValue();

        EcpayProperties properties = new EcpayProperties();
        properties.setMerchantId(MERCHANT_ID);
        properties.setHashKey(HASH_KEY);
        properties.setHashIv(HASH_IV);
        properties.setPaymentUrl("https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5");
        properties.setReturnUrl("https://callback.example.test/api/payments/ecpay/return");
        properties.setOrderResultUrl("https://callback.example.test/api/payments/ecpay/order-result");
        properties.setCheckoutSuccessUrl("https://storefront.example.test/checkout-success.html");

        service = new PaymentService(orders, paymentTransactions, properties, checkMacValue);
    }

    @Test
    void validSuccessfulCallbackMarksTransactionAndOrderPaid() {
        Order order = unpaidOrder();
        PaymentTransaction transaction = new PaymentTransaction(
                order, MERCHANT_TRADE_NO, new BigDecimal("100.00"), OffsetDateTime.parse("2026-07-21T12:00:00+08:00"));
        when(paymentTransactions.findByMerchantTradeNo(MERCHANT_TRADE_NO)).thenReturn(Optional.of(transaction));

        String response = service.handleEcpayReturn(validCallback());

        assertThat(response).isEqualTo("1|OK");
        assertThat(transaction.getStatus()).isEqualTo("paid");
        assertThat(transaction.getGatewayTradeNo()).isEqualTo(GATEWAY_TRADE_NO);
        assertThat(transaction.getCallbackReceivedAt()).isNotNull();
        assertThat(transaction.getPaidAt()).isEqualTo(OffsetDateTime.parse("2026-07-21T12:34:56+08:00"));
        assertThat(order.getPaymentStatus()).isEqualTo(PaymentStatus.paid);
    }

    @Test
    void paidTransactionIsIdempotent() {
        Order order = unpaidOrder();
        PaymentTransaction transaction = new PaymentTransaction(
                order, MERCHANT_TRADE_NO, new BigDecimal("100.00"), OffsetDateTime.parse("2026-07-21T12:00:00+08:00"));
        transaction.markPaid(GATEWAY_TRADE_NO,
                OffsetDateTime.parse("2026-07-21T12:10:00+08:00"),
                OffsetDateTime.parse("2026-07-21T12:10:00+08:00"));
        when(paymentTransactions.findByMerchantTradeNo(MERCHANT_TRADE_NO)).thenReturn(Optional.of(transaction));

        String response = service.handleEcpayReturn(validCallback());

        assertThat(response).isEqualTo("1|OK");
        assertThat(transaction.getPaidAt()).isEqualTo(OffsetDateTime.parse("2026-07-21T12:10:00+08:00"));
    }

    @Test
    void invalidCheckMacValueDoesNotUpdateDatabaseState() {
        Order order = unpaidOrder();
        PaymentTransaction transaction = new PaymentTransaction(
                order, MERCHANT_TRADE_NO, new BigDecimal("100.00"), OffsetDateTime.parse("2026-07-21T12:00:00+08:00"));
        Map<String, String> callback = validCallback();
        callback.put("CheckMacValue", "BAD");

        assertThatThrownBy(() -> service.handleEcpayReturn(callback))
                .isInstanceOf(ResponseStatusException.class);

        assertThat(transaction.getStatus()).isEqualTo("pending");
        assertThat(order.getPaymentStatus()).isEqualTo(PaymentStatus.unpaid);
    }

    @Test
    void simulatedPaymentDoesNotMarkPaid() {
        Order order = unpaidOrder();
        PaymentTransaction transaction = new PaymentTransaction(
                order, MERCHANT_TRADE_NO, new BigDecimal("100.00"), OffsetDateTime.parse("2026-07-21T12:00:00+08:00"));
        when(paymentTransactions.findByMerchantTradeNo(MERCHANT_TRADE_NO)).thenReturn(Optional.of(transaction));
        Map<String, String> callback = validCallback();
        callback.put("SimulatePaid", "1");
        callback.put("CheckMacValue", checkMacValue.generate(callback, HASH_KEY, HASH_IV));

        assertThatThrownBy(() -> service.handleEcpayReturn(callback))
                .isInstanceOf(ResponseStatusException.class);

        assertThat(transaction.getStatus()).isEqualTo("pending");
        assertThat(order.getPaymentStatus()).isEqualTo(PaymentStatus.unpaid);
    }

    private Map<String, String> validCallback() {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("MerchantID", MERCHANT_ID);
        fields.put("MerchantTradeNo", MERCHANT_TRADE_NO);
        fields.put("RtnCode", "1");
        fields.put("RtnMsg", "Succeeded");
        fields.put("TradeNo", GATEWAY_TRADE_NO);
        fields.put("TradeAmt", "100");
        fields.put("PaymentDate", "2026/07/21 12:34:56");
        fields.put("PaymentType", "Credit_CreditCard");
        fields.put("PaymentTypeChargeFee", "1");
        fields.put("TradeDate", "2026/07/21 12:00:00");
        fields.put("SimulatePaid", "0");
        fields.put("TotalAmount", "100");
        fields.put("CheckMacValue", checkMacValue.generate(fields, HASH_KEY, HASH_IV));
        return fields;
    }

    private Order unpaidOrder() {
        Instant now = OffsetDateTime.parse("2026-07-21T12:00:00+08:00").toInstant();
        Order order = new Order();
        order.initialize(
                "O202607210001",
                "C001",
                null,
                null,
                "Buyer",
                "buyer@example.test",
                "Receiver",
                "Taipei",
                "0912345678",
                PaymentMethod.ecpay_credit,
                now,
                null);
        order.setPricing(new BigDecimal("100.00"), BigDecimal.ZERO.setScale(2), BigDecimal.ZERO.setScale(2));
        return order;
    }
}
