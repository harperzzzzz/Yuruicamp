package com.yuruicamp.backend.inventory.infrastructure;
import java.util.List;
import com.yuruicamp.backend.inventory.domain.InventoryStock;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface InventoryStockRepository extends JpaRepository<InventoryStock,InventoryStock.Key> {
	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select s from InventoryStock s where s.variantId=:variantId and s.inventoryDomain='store' order by s.locationId")
	List<InventoryStock> lockStoreStocksByVariantId(@Param("variantId") String variantId);
}
