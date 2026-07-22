package com.yuruicamp.backend.coupon.domain;

import java.math.BigDecimal;
import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

// 保存訂單套券當下的折扣快照。
@Entity
@Table(name = "order_coupons")
public class OrderCoupon {

	@Id
	@GeneratedValue(strategy = GenerationType.IDENTITY)
	private Long id;

	@Column(name = "order_id", nullable = false, length = 32)
	private String orderId;

	@Column(name = "coupon_id", nullable = false)
	private Long couponId;

	@Column(name = "coupon_claim_id", nullable = false)
	private Long couponClaimId;

	@Column(name = "code_snapshot", nullable = false, length = 64)
	private String codeSnapshot;

	@Column(name = "discount_type_snapshot", nullable = false, length = 16)
	private String discountTypeSnapshot;

	@Column(name = "discount_value_snapshot", nullable = false)
	private BigDecimal discountValueSnapshot;

	@Column(nullable = false)
	private BigDecimal amount;

	@Column(name = "applied_at", nullable = false)
	private Instant appliedAt;

	public static OrderCoupon snapshot(String orderId, Coupon coupon, Long claimId,
			BigDecimal amount, Instant now) {
		OrderCoupon snapshot = new OrderCoupon();
		snapshot.orderId = orderId;
		snapshot.couponId = coupon.getId();
		snapshot.couponClaimId = claimId;
		snapshot.codeSnapshot = coupon.getCode();
		snapshot.discountTypeSnapshot = coupon.getDiscountType();
		snapshot.discountValueSnapshot = coupon.getDiscountValue();
		snapshot.amount = amount;
		snapshot.appliedAt = now;

		return snapshot;
	}

	public String getOrderId() {
		return orderId;
	}

	public Long getCouponClaimId() {
		return couponClaimId;
	}
}
