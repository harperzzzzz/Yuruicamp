package com.yuruicamp.backend.catalog.domain;

import java.time.Instant;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * product_categories — category master (帐篷 / 睡袋 …).
 * 分類主檔（顯示名稱給商品 API 的 category 欄位）。
 */
@Entity
@Table(name = "product_categories")
public class ProductCategory {

	@Id
	private Long id;

	@Column(nullable = false, length = 64)
	private String code;

	@Column(nullable = false, length = 100)
	private String name;

	@Column(name = "sort_order", nullable = false)
	private int sortOrder;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	public Long getId() {
		return id;
	}

	public String getName() {
		return name;
	}
}
