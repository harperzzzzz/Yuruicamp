package com.yuruicamp.backend.catalog.domain;

import java.math.BigDecimal;
import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * product_variants — sellable SKU (real price lives here).
 * 商品規格 SKU：契約 variants[] 的來源；售價在這一層。
 */
@Entity
@Table(name = "product_variants")
public class ProductVariant {

	@Id
	@Column(length = 64)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "product_id", nullable = false)
	private Product product;

	@Column(nullable = false, length = 64)
	private String sku;

	@Column(length = 100)
	private String color;

	@Column(length = 100)
	private String size;

	@Column(nullable = false, precision = 12, scale = 2)
	private BigDecimal price;

	@Column(nullable = false, length = 200)
	private String specification;

	@Column(nullable = false, length = 16)
	private String status;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	public String getId() {
		return id;
	}

	public Product getProduct() {
		return product;
	}

	public String getSku() {
		return sku;
	}

	public String getColor() {
		return color;
	}

	public String getSize() {
		return size;
	}

	public BigDecimal getPrice() {
		return price;
	}

	public String getSpecification() {
		return specification;
	}

	public String getStatus() {
		return status;
	}
}
