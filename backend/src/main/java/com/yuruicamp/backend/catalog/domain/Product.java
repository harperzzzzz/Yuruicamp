package com.yuruicamp.backend.catalog.domain;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

/**
 * products — storefront SPU (sellable identity pointing at equipment_items).
 * 商城商品 SPU：本身幾乎只有狀態 + 指向裝備；名稱在 equipment_items。
 */
@Entity
@Table(name = "products")
public class Product {

	@Id
	@Column(length = 32)
	private String id;

	@Column(nullable = false, length = 16)
	private String status;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "item_id", nullable = false)
	private EquipmentItem item;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	@OneToMany(mappedBy = "product", fetch = FetchType.LAZY)
	private List<ProductVariant> variants = new ArrayList<>();

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public String getStatus() {
		return status;
	}

	public void setStatus(String status) {
		this.status = status;
	}

	public EquipmentItem getItem() {
		return item;
	}

	public void setItem(EquipmentItem item) {
		this.item = item;
	}

	public List<ProductVariant> getVariants() {
		return variants;
	}

	public Instant getCreatedAt() {
		return createdAt;
	}

	public void setCreatedAt(Instant createdAt) {
		this.createdAt = createdAt;
	}

	public Instant getUpdatedAt() {
		return updatedAt;
	}

	public void setUpdatedAt(Instant updatedAt) {
		this.updatedAt = updatedAt;
	}
}
