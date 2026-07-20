package com.yuruicamp.backend.catalog.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.IdClass;
import jakarta.persistence.Table;

/**
 * equipment_images — sort_order = 0 is the main image for Product.image.
 * 裝備圖片；契約 v0.1 只取主圖（sort_order = 0）。
 */
@Entity
@Table(name = "equipment_images")
@IdClass(EquipmentImage.Pk.class)
public class EquipmentImage {

	@Id
	@Column(name = "item_id", length = 32)
	private String itemId;

	@Id
	@Column(name = "sort_order")
	private int sortOrder;

	@Column(nullable = false)
	private String url;

	@Column(name = "alt_text", length = 200)
	private String altText;

	@Column(name = "created_at", nullable = false)
	private Instant createdAt;

	@Column(name = "updated_at", nullable = false)
	private Instant updatedAt;

	public String getItemId() {
		return itemId;
	}

	public int getSortOrder() {
		return sortOrder;
	}

	public String getUrl() {
		return url;
	}

	/** Composite primary key for (item_id, sort_order). */
	public static class Pk implements Serializable {

		private String itemId;
		private int sortOrder;

		public Pk() {
		}

		public Pk(String itemId, int sortOrder) {
			this.itemId = itemId;
			this.sortOrder = sortOrder;
		}

		@Override
		public boolean equals(Object o) {
			if (this == o) {
				return true;
			}
			if (!(o instanceof Pk pk)) {
				return false;
			}
			return sortOrder == pk.sortOrder && Objects.equals(itemId, pk.itemId);
		}

		@Override
		public int hashCode() {
			return Objects.hash(itemId, sortOrder);
		}
	}
}
