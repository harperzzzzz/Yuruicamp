package com.yuruicamp.backend.entity;

import com.yuruicamp.backend.order.domain.Order;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import org.hibernate.annotations.ColumnTransformer;

@Entity
@Table(name = "payment_transactions")
public class PaymentTransaction {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", nullable = false)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "gateway", length = 24, nullable = false)
    private String gateway;

    @Column(name = "merchant_trade_no", length = 20, nullable = false, unique = true)
    private String merchantTradeNo;

    @Column(name = "gateway_trade_no", length = 64)
    private String gatewayTradeNo;

    @Column(name = "amount", precision = 14, scale = 2, nullable = false)
    private BigDecimal amount;

    @Column(name = "currency", length = 3, nullable = false)
    private String currency;

    @Column(name = "payment_method", nullable = false, columnDefinition = "payment_method")
    @ColumnTransformer(write = "?::public.payment_method")
    private String paymentMethod;

    @Column(name = "status", length = 24, nullable = false)
    private String status;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @Column(name = "callback_received_at")
    private OffsetDateTime callbackReceivedAt;

    @Column(name = "paid_at")
    private OffsetDateTime paidAt;

    protected PaymentTransaction() {
    }

    public PaymentTransaction(Order order, String merchantTradeNo, BigDecimal amount, OffsetDateTime now) {
        this.order = order;
        this.gateway = "ECPAY";
        this.merchantTradeNo = merchantTradeNo;
        this.amount = amount;
        this.currency = "TWD";
        this.paymentMethod = "ecpay-credit";
        this.status = "pending";
        this.createdAt = now;
        this.updatedAt = now;
    }

    public Long getId() {
        return id;
    }

    public Order getOrder() {
        return order;
    }

    public String getMerchantTradeNo() {
        return merchantTradeNo;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public String getCurrency() {
        return currency;
    }

    public String getStatus() {
        return status;
    }

    public String getGatewayTradeNo() {
        return gatewayTradeNo;
    }

    public OffsetDateTime getCallbackReceivedAt() {
        return callbackReceivedAt;
    }

    public OffsetDateTime getPaidAt() {
        return paidAt;
    }

    public boolean isPaid() {
        return "paid".equalsIgnoreCase(status);
    }

    public void markPaid(String gatewayTradeNo, OffsetDateTime callbackReceivedAt, OffsetDateTime paidAt) {
        this.status = "paid";
        this.gatewayTradeNo = gatewayTradeNo;
        this.callbackReceivedAt = callbackReceivedAt;
        this.paidAt = paidAt;
        this.updatedAt = callbackReceivedAt;
    }
}
