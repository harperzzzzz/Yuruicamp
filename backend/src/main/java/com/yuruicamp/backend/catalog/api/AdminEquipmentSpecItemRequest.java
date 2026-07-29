package com.yuruicamp.backend.catalog.api;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 裝備規格單筆鍵值輸入，例如 {@code key="weight", value="4.2 kg"}。
 * Admin equipment specification key-value input.
 */
public record AdminEquipmentSpecItemRequest(
		@NotBlank @Size(max = 100) String key,
		@NotBlank @Size(max = 1000) String value) {
}
