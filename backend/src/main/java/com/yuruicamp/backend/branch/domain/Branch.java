package com.yuruicamp.backend.branch.domain;

import java.math.BigDecimal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * 用途：對應門市主檔，提供公開門市查詢。
 * 核心重點：Entity 只描述資料表欄位，不直接作為 API 回應。
 */
@Entity
@Table(name = "branches")
public class Branch {

	@Id
	@Column(length = 32)
	private String id;

	@Column(nullable = false, length = 120)
	private String name;

	@Column(nullable = false, length = 300)
	private String address;

	@Column(nullable = false, length = 32)
	private String phone;

	@Column(precision = 10, scale = 6)
	private BigDecimal latitude;

	@Column(precision = 10, scale = 6)
	private BigDecimal longitude;

	@Column(name = "map_query")
	private String mapQuery;

	@Column(name = "business_hours", nullable = false, length = 200)
	private String businessHours;

	@Column(name = "image_url")
	private String imageUrl;

	/** 是否啟用；停用後不再出現在公開列表，但保留給訂單取貨與庫位關聯查詢歷史。 */
	@Column(nullable = false)
	private boolean active;

	protected Branch() {
	}

	public String getId() {
		return id;
	}

	public String getName() {
		return name;
	}

	public String getAddress() {
		return address;
	}

	public String getPhone() {
		return phone;
	}

	public BigDecimal getLatitude() {
		return latitude;
	}

	public BigDecimal getLongitude() {
		return longitude;
	}

	public String getMapQuery() {
		return mapQuery;
	}

	public String getBusinessHours() {
		return businessHours;
	}

	public String getImageUrl() {
		return imageUrl;
	}

	public boolean isActive() {
		return active;
	}
}
