package com.yuruicamp.backend.inventory.infrastructure;
import java.time.Instant;
import java.util.List;
import com.yuruicamp.backend.inventory.domain.ProductStockReservation;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
public interface ProductStockReservationRepository extends JpaRepository<ProductStockReservation,Long> {
	@Query("select coalesce(sum(r.quantity),0) from ProductStockReservation r where r.variantId=:variantId and r.locationId=:locationId and r.status='active'") int activeQuantity(@Param("variantId") String variantId,@Param("locationId") String locationId);
	@Query("select r from ProductStockReservation r where r.status='active' and r.expiresAt < :now") List<ProductStockReservation> findExpiredActive(@Param("now") Instant now);
	@Query("select r from ProductStockReservation r where r.status='active' and r.orderItemId in :orderItemIds") List<ProductStockReservation> findActiveByOrderItemIdIn(@Param("orderItemIds") List<Long> orderItemIds);
}
