package com.yuruicamp.backend.service;

import com.yuruicamp.backend.config.EcpayProperties;
import com.yuruicamp.backend.dto.CreatePaymentRequest;
import com.yuruicamp.backend.dto.CreatePaymentResponse;
import com.yuruicamp.backend.entity.Order;
import com.yuruicamp.backend.entity.PaymentTransaction;
import com.yuruicamp.backend.payment.EcpayCheckMacValue;
import com.yuruicamp.backend.repository.OrderRepository;
import com.yuruicamp.backend.repository.PaymentTransactionRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class PaymentService {

    private static final ZoneId TAIPEI_ZONE = ZoneId.of("Asia/Taipei");
    private static final DateTimeFormatter ECPAY_DATE_FORMAT =
            DateTimeFormatter.ofPattern("yyyy/MM/dd HH:mm:ss").withZone(TAIPEI_ZONE);
    private static final int MERCHANT_TRADE_NO_MAX_ATTEMPTS = 5;

    private final OrderRepository orderRepository;
    private final PaymentTransactionRepository paymentTransactionRepository;
    private final EcpayProperties ecpayProperties;
    private final EcpayCheckMacValue ecpayCheckMacValue;

    public PaymentService(OrderRepository orderRepository,
            PaymentTransactionRepository paymentTransactionRepository,
            EcpayProperties ecpayProperties,
            EcpayCheckMacValue ecpayCheckMacValue) {
        this.orderRepository = orderRepository;
        this.paymentTransactionRepository = paymentTransactionRepository;
        this.ecpayProperties = ecpayProperties;
        this.ecpayCheckMacValue = ecpayCheckMacValue;
    }

    @Transactional
    public CreatePaymentResponse createPayment(CreatePaymentRequest request) {
        requireEcpayConfig();

        Order order = orderRepository.findById(request.orderId())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND,
                        "Order not found: " + request.orderId()));
        if (!"unpaid".equalsIgnoreCase(order.getPaymentStatus())) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "Only unpaid orders can create ECPay payment transactions.");
        }

        BigDecimal amount = normalizeIntegerTwdAmount(order.getTotal());
        OffsetDateTime now = OffsetDateTime.now(TAIPEI_ZONE);
        PaymentTransaction transaction = savePendingTransaction(order, amount, now);
        Map<String, String> formFields = buildFormFields(order, transaction, now);
        String formHtml = buildAutoSubmitForm(ecpayProperties.getPaymentUrl(), formFields);

        return new CreatePaymentResponse(
                transaction.getId(),
                order.getId(),
                transaction.getMerchantTradeNo(),
                transaction.getAmount(),
                transaction.getCurrency(),
                transaction.getStatus(),
                ecpayProperties.getPaymentUrl(),
                formHtml,
                formFields
        );
    }

    private void requireEcpayConfig() {
        if (isBlank(ecpayProperties.getMerchantId())
                || isBlank(ecpayProperties.getHashKey())
                || isBlank(ecpayProperties.getHashIv())
                || isBlank(ecpayProperties.getPaymentUrl())
                || isBlank(ecpayProperties.getReturnUrl())) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                    "ECPay configuration is incomplete.");
        }
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    private BigDecimal normalizeIntegerTwdAmount(BigDecimal total) {
        BigDecimal normalized = total.setScale(2, RoundingMode.UNNECESSARY);
        if (normalized.compareTo(BigDecimal.ZERO) <= 0 || normalized.stripTrailingZeros().scale() > 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST,
                    "ECPay AIO Sandbox requires a positive integer TWD amount.");
        }
        return normalized;
    }

    private PaymentTransaction savePendingTransaction(Order order, BigDecimal amount, OffsetDateTime now) {
        for (int attempt = 0; attempt < MERCHANT_TRADE_NO_MAX_ATTEMPTS; attempt++) {
            String merchantTradeNo = buildMerchantTradeNo(now, attempt);
            if (paymentTransactionRepository.existsByMerchantTradeNo(merchantTradeNo)) {
                continue;
            }
            try {
                PaymentTransaction transaction = new PaymentTransaction(order, merchantTradeNo, amount, now);
                return paymentTransactionRepository.saveAndFlush(transaction);
            } catch (DataIntegrityViolationException ex) {
                if (attempt == MERCHANT_TRADE_NO_MAX_ATTEMPTS - 1) {
                    throw ex;
                }
            }
        }
        throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR,
                "Unable to generate a unique MerchantTradeNo.");
    }

    private String buildMerchantTradeNo(OffsetDateTime now, int attempt) {
        String timestamp = DateTimeFormatter.ofPattern("yyMMddHHmmssSSS").format(now);
        String suffix = Integer.toString(attempt, 36).toUpperCase(Locale.ROOT);
        return ("YRC" + timestamp + suffix).substring(0, 20);
    }

    private Map<String, String> buildFormFields(Order order, PaymentTransaction transaction, OffsetDateTime now) {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("MerchantID", ecpayProperties.getMerchantId());
        fields.put("MerchantTradeNo", transaction.getMerchantTradeNo());
        fields.put("MerchantTradeDate", ECPAY_DATE_FORMAT.format(now));
        fields.put("PaymentType", "aio");
        fields.put("TotalAmount", transaction.getAmount().setScale(0, RoundingMode.UNNECESSARY).toPlainString());
        fields.put("TradeDesc", "Yuruicamp order payment");
        fields.put("ItemName", "Yuruicamp order " + order.getId());
        fields.put("ReturnURL", ecpayProperties.getReturnUrl());
        fields.put("ChoosePayment", "Credit");
        fields.put("EncryptType", "1");
        fields.put("CheckMacValue", ecpayCheckMacValue.generate(
                fields, ecpayProperties.getHashKey(), ecpayProperties.getHashIv()));
        return fields;
    }

    private String buildAutoSubmitForm(String action, Map<String, String> fields) {
        StringBuilder html = new StringBuilder();
        html.append("<!doctype html><html><head><meta charset=\"utf-8\"><title>ECPay Redirect</title></head><body>");
        html.append("<form id=\"ecpayForm\" method=\"post\" action=\"").append(escapeHtml(action)).append("\">");
        fields.forEach((key, value) -> html.append("<input type=\"hidden\" name=\"")
                .append(escapeHtml(key))
                .append("\" value=\"")
                .append(escapeHtml(value))
                .append("\">"));
        html.append("<noscript><button type=\"submit\">Continue to ECPay</button></noscript>");
        html.append("</form><script>document.getElementById('ecpayForm').submit();</script>");
        html.append("</body></html>");
        return html.toString();
    }

    private String escapeHtml(String value) {
        return value
                .replace("&", "&amp;")
                .replace("\"", "&quot;")
                .replace("<", "&lt;")
                .replace(">", "&gt;");
    }
}
