package com.yuruicamp.backend.catalog.api;

import java.util.List;

import jakarta.validation.constraints.NotNull;

/**
 * 依 {@code itemId} 整組取代裝備查詢／特色標籤（{@code equipment_tags}，W2-04）。
 * Admin equipment tags replace input.
 *
 * <p>語意固定<b>整組取代</b>：body 出現的標籤 → 新增；DB 已存在但沒出現的 → 刪除；
 * {@code tags: []} → 清空全部。大小寫視為同一個標籤（DB 有
 * {@code UNIQUE (item_id, lower(btrim(tag)))}），重複時後端會自動去重，
 * 保留第一次出現的原始大小寫。</p>
 */
public record AdminEquipmentTagsRequest(@NotNull List<String> tags) {
}
