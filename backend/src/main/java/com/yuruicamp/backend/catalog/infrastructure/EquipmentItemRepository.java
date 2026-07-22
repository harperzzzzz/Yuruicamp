package com.yuruicamp.backend.catalog.infrastructure;

import com.yuruicamp.backend.catalog.domain.EquipmentItem;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 裝備主檔寫入入口，供後台商品交易維護名稱、分類、品牌與描述。
 */
public interface EquipmentItemRepository extends JpaRepository<EquipmentItem, String> {
}
