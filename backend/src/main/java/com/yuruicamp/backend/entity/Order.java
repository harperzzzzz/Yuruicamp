package com.yuruicamp.backend.entity;

import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import org.hibernate.annotations.ColumnTransformer;

@Entity
@Table(name = "orders")
public class Order {

    @Id
    @Column(name = "id", length = 32, nullable = false)
    private String id;

    @Column(name = "customer_id", length = 32, nullable = false)
    private String customerId;

    @Column(name = "buyer_name_snapshot", length = 100, nullable = false)
    private String buyerNameSnapshot;

    @Column(name = "buyer_email_snapshot", length = 254, nullable = false)
    private String buyerEmailSnapshot;

    @Column(name = "recipient_name_snapshot", length = 100, nullable = false)
    private String recipientNameSnapshot;

    @Column(name = "shipping_address_snapshot", nullable = false)
    private String shippingAddressSnapshot;

    @Column(name = "shipping_phone_snapshot", length = 32, nullable = false)
    private String shippingPhoneSnapshot;

    @Column(name = "subtotal", precision = 14, scale = 2, nullable = false)
    private BigDecimal subtotal;

    @Column(name = "shipping_fee", precision = 12, scale = 2, nullable = false)
    private BigDecimal shippingFee;

    @Column(name = "discount", precision = 14, scale = 2, nullable = false)
    private BigDecimal discount;

    @Column(name = "total", precision = 14, scale = 2, nullable = false)
    private BigDecimal total;

    @Column(name = "payment_method", nullable = false, columnDefinition = "payment_method")
    @ColumnTransformer(write = "?::public.payment_method")
    private String paymentMethod;

    @Column(name = "payment_status", nullable = false, columnDefinition = "payment_status")
    @ColumnTransformer(write = "?::public.payment_status")
    private String paymentStatus;

    @Column(name = "refund_status", nullable = false, columnDefinition = "refund_status")
    @ColumnTransformer(write = "?::public.refund_status")
    private String refundStatus;

    @Column(name = "status", nullable = false, columnDefinition = "order_status")
    @ColumnTransformer(write = "?::public.order_status")
    private String status;

    @Column(name = "placed_at", nullable = false)
    private OffsetDateTime placedAt;

    @Column(name = "paid_at")
    private OffsetDateTime paidAt;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    protected Order() {
    }

    public Order(String id, String customerId, String buyerNameSnapshot, String buyerEmailSnapshot,
            String recipientNameSnapshot, String shippingAddressSnapshot, String shippingPhoneSnapshot,
            BigDecimal subtotal, BigDecimal shippingFee, BigDecimal discount, BigDecimal total,
            String paymentMethod, String paymentStatus, String refundStatus, String status,
            OffsetDateTime placedAt, OffsetDateTime createdAt, OffsetDateTime updatedAt) {
        this.id = id;
        this.customerId = customerId;
        this.buyerNameSnapshot = buyerNameSnapshot;
        this.buyerEmailSnapshot = buyerEmailSnapshot;
        this.recipientNameSnapshot = recipientNameSnapshot;
        this.shippingAddressSnapshot = shippingAddressSnapshot;
        this.shippingPhoneSnapshot = shippingPhoneSnapshot;
        this.subtotal = subtotal;
        this.shippingFee = shippingFee;
        this.discount = discount;
        this.total = total;
        this.paymentMethod = paymentMethod;
        this.paymentStatus = paymentStatus;
        this.refundStatus = refundStatus;
        this.status = status;
        this.placedAt = placedAt;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    public void addItem(OrderItem item) {
        items.add(item);
        item.assignOrder(this);
    }

    public void updateTotals(BigDecimal subtotal, BigDecimal shippingFee, BigDecimal discount) {
        this.subtotal = subtotal;
        this.shippingFee = shippingFee;
        this.discount = discount;
        BigDecimal calculatedTotal = subtotal.add(shippingFee).subtract(discount);
        this.total = calculatedTotal.max(BigDecimal.ZERO).setScale(2);
    }

    public String getId() {
        return id;
    }

    public BigDecimal getTotal() {
        return total;
    }

    public String getPaymentMethod() {
        return paymentMethod;
    }

    public String getPaymentStatus() {
        return paymentStatus;
    }

    public void markPaid(OffsetDateTime paidAt) {
        this.paymentStatus = "paid";
        this.paidAt = paidAt;
        this.updatedAt = paidAt;
    }
}
