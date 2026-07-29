package com.yuruicamp.backend.catalog.api;

import java.util.List;

/** 裝備標籤整組回應：依標籤字母排序。 */
public record AdminEquipmentTagsResponse(String itemId, List<String> tags) {
}
