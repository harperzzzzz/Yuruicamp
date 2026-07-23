package com.yuruicamp.backend.catalog.api;

import java.util.List;

/** 裝備規格整組回應：依 {@code spec_key} 排序。 */
public record AdminEquipmentSpecsResponse(String itemId, List<AdminEquipmentSpecItemResponse> specs) {
}
