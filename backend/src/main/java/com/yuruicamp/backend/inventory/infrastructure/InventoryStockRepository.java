package com.yuruicamp.backend.inventory.infrastructure;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.yuruicamp.backend.inventory.domain.InventoryStock;

import jakarta.persistence.LockModeType;

public interface InventoryStockRepository extends JpaRepository<InventoryStock,InventoryStock.Key> {
	/**
	 * 用途：依商品規格 ID 查詢所有門市庫存，並依據庫存地點 ID 排序。
	 * 核心重點：使用悲觀寫入鎖鎖住查到的庫存列，避免結帳併發時多個交易同時占用相同庫存。
	 */
	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select s from InventoryStock s where s.variantId=:variantId and s.inventoryDomain='store' order by s.locationId")
	List<InventoryStock> lockStoreStocksByVariantId(@Param("variantId") String variantId);
}
