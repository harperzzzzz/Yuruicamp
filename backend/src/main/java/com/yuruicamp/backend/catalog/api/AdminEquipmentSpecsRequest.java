package com.yuruicamp.backend.catalog.api;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

/**
 * 依 {@code itemId} 整組取代裝備規格（W2-04）。
 * Admin equipment specifications replace input.
 *
 * <p>語意固定<b>整組取代</b>：body 出現的 key → 新增或更新其 value；
 * DB 已存在但這次沒出現的 key → <b>直接刪除</b>（跟會員標籤指派、偏好取代一樣的規則，
 * 差別是這裡的表沒有 {@code active} 欄位可軟停用，所以「沒出現＝刪除」）。
 * {@code specs: []} 代表清空這個裝備的全部規格。</p>
 */
public record AdminEquipmentSpecsRequest(
		@NotNull List<@Valid AdminEquipmentSpecItemRequest> specs) {
}
