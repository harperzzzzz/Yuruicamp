package com.yuruicamp.backend.order.domain;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "orders")
public class Order {
	@Id @Column(length = 32) private String id;
	@Column(name = "customer_id", nullable = false, length = 32) private String customerId;
	@Column(name = "buyer_name_snapshot", nullable = false) private String buyerName;
	@Column(name = "buyer_email_snapshot", nullable = false) private String buyerEmail;
	@Column(name = "recipient_name_snapshot", nullable = false) private String recipientName;
	@Column(name = "shipping_address_snapshot", nullable = false) private String shippingAddress;
	@Column(name = "shipping_phone_snapshot", nullable = false) private String shippingPhone;
	@Column(nullable = false) private BigDecimal subtotal;
	@Column(name = "shipping_fee", nullable = false) private BigDecimal shippingFee;
	@Column(nullable = false) private BigDecimal discount;
	@Column(nullable = false) private BigDecimal total;
	@Convert(converter = PaymentMethodConverter.class) @Column(name = "payment_method", nullable = false, columnDefinition = "payment_method") private PaymentMethod paymentMethod;
	@Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM) @Column(name = "payment_status", nullable = false, columnDefinition = "payment_status") private PaymentStatus paymentStatus;
	@Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM) @Column(name = "refund_status", nullable = false, columnDefinition = "refund_status") private RefundStatus refundStatus;
	@Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM) @Column(nullable = false, columnDefinition = "order_status") private OrderStatus status;
	@Column(name = "placed_at", nullable = false) private Instant placedAt;
	@Column(name = "paid_at") private Instant paidAt;
	@Column(name = "checkout_expires_at") private Instant checkoutExpiresAt;
	@OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true) private List<OrderItem> items = new ArrayList<>();
	public String getId(){return id;} public String getCustomerId(){return customerId;} public List<OrderItem> getItems(){return items;}
	public PaymentMethod getPaymentMethod(){return paymentMethod;} public PaymentStatus getPaymentStatus(){return paymentStatus;} public RefundStatus getRefundStatus(){return refundStatus;} public OrderStatus getStatus(){return status;}
	public String getBuyerName(){return buyerName;} public String getBuyerEmail(){return buyerEmail;} public String getRecipientName(){return recipientName;} public String getShippingAddress(){return shippingAddress;} public String getShippingPhone(){return shippingPhone;}
	public BigDecimal getSubtotal(){return subtotal;} public BigDecimal getShippingFee(){return shippingFee;} public BigDecimal getDiscount(){return discount;} public BigDecimal getTotal(){return total;} public Instant getPlacedAt(){return placedAt;} public Instant getPaidAt(){return paidAt;} public Instant getCheckoutExpiresAt(){return checkoutExpiresAt;}
	public void initialize(String id,String customerId,String buyerName,String buyerEmail,String recipientName,String shippingAddress,String shippingPhone,PaymentMethod paymentMethod,Instant now,Instant expiresAt){this.id=id;this.customerId=customerId;this.buyerName=buyerName;this.buyerEmail=buyerEmail;this.recipientName=recipientName;this.shippingAddress=shippingAddress;this.shippingPhone=shippingPhone;this.paymentMethod=paymentMethod;this.paymentStatus=PaymentStatus.unpaid;this.refundStatus=RefundStatus.none;this.status=OrderStatus.unshipped;this.placedAt=now;this.checkoutExpiresAt=expiresAt;this.subtotal=BigDecimal.ZERO;this.shippingFee=BigDecimal.ZERO;this.discount=BigDecimal.ZERO;this.total=BigDecimal.ZERO;}
	public void setPricing(BigDecimal subtotal,BigDecimal shippingFee,BigDecimal discount){this.subtotal=subtotal;this.shippingFee=shippingFee;this.discount=discount;this.total=subtotal.add(shippingFee).subtract(discount).max(BigDecimal.ZERO);}
	public void addItem(OrderItem item){items.add(item);}
	public void cancel(){this.status=OrderStatus.cancelled;}
}
