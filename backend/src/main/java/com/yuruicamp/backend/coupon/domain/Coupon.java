package com.yuruicamp.backend.coupon.domain;

import java.math.BigDecimal;
import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

// 保存優惠券主檔與領取名額計數。
@Entity
@Table(name = "coupons")
public class Coupon {

	@Id
	private Long id;

	@Column(nullable = false, length = 64)
	private String code;

	@Column(nullable = false, length = 120)
	private String name;

	@Column(name = "discount_type", nullable = false, length = 16)
	private String discountType;

	@Column(name = "discount_value", nullable = false)
	private BigDecimal discountValue;

	@Column(name = "minimum_amount", nullable = false)
	private BigDecimal minimumAmount;

	@Column(name = "issue_quantity", nullable = false)
	private int issueQuantity;

	@Column(name = "claimed_quantity", nullable = false)
	private int claimedQuantity;

	@Column(name = "valid_from", nullable = false)
	private Instant validFrom;

	@Column(name = "valid_until", nullable = false)
	private Instant validUntil;

	@Enumerated(EnumType.STRING)
	@JdbcTypeCode(SqlTypes.NAMED_ENUM)
	@Column(nullable = false, columnDefinition = "coupon_status")
	private CouponStatus status;

	@Enumerated(EnumType.STRING)
	@JdbcTypeCode(SqlTypes.NAMED_ENUM)
	@Column(nullable = false, columnDefinition = "coupon_category")
	private CouponCategory category;

	public Long getId() {
		return id;
	}

	public String getCode() {
		return code;
	}

	public String getName() {
		return name;
	}

	public String getDiscountType() {
		return discountType;
	}

	public BigDecimal getDiscountValue() {
		return discountValue;
	}

	public BigDecimal getMinimumAmount() {
		return minimumAmount;
	}

	public int getIssueQuantity() {
		return issueQuantity;
	}

	public int getClaimedQuantity() {
		return claimedQuantity;
	}

	public Instant getValidFrom() {
		return validFrom;
	}

	public Instant getValidUntil() {
		return validUntil;
	}

	public CouponStatus getStatus() {
		return status;
	}

	public CouponCategory getCategory() {
		return category;
	}
}
