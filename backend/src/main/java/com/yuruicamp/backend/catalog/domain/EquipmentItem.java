package com.yuruicamp.backend.catalog.domain;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * equipment_items — shared equipment master (name / description / brand / category).
 * 裝備共用主檔：商品名稱等展示欄位從這裡來，不是 products 表。
 */
@Entity
@Table(name = "equipment_items")
public class EquipmentItem {

	@Id
	@Column(length = 32)
	private String id;

	@ManyToOne(fetch = FetchType.LAZY, optional = false)
	@JoinColumn(name = "category_id", nullable = false)
	private ProductCategory category;

	@ManyToOne(fetch = FetchType.LAZY)
	@JoinColumn(name = "brand_id")
	private Brand brand;

	@Column(nullable = false, length = 200)
	private String name;

	private String description;

	@Column(nullable = false)
	private boolean active;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	public String getId() {
		return id;
	}

	public ProductCategory getCategory() {
		return category;
	}

	public Brand getBrand() {
		return brand;
	}

	public String getName() {
		return name;
	}

	public String getDescription() {
		return description;
	}

	public boolean isActive() {
		return active;
	}
}
