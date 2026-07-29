package com.yuruicamp.backend.catalog.infrastructure;

import java.util.Collection;
import java.util.List;

import com.yuruicamp.backend.catalog.domain.ProductVariant;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 用途：查詢每個商品規格扣除有效保留量後的可售庫存。
 * 核心重點：以 variant 為粒度加總多個商城庫位，終止狀態的保留帳不會扣庫存。
 */
public interface VariantAvailabilityRepository extends JpaRepository<ProductVariant, String> {

	@Query(value = """
			select variant.id as variantId,
			       greatest(
			           coalesce(stock.on_hand_quantity, 0) - coalesce(reservation.reserved_quantity, 0),
			           0
			       ) as availableQuantity
			from product_variants variant
			left join (
			    select variant_id, sum(on_hand_quantity) as on_hand_quantity
			    from inventory_stocks
			    group by variant_id
			) stock on stock.variant_id = variant.id
			left join (
			    select variant_id, sum(quantity) as reserved_quantity
			    from product_stock_reservations
			    where status = 'active'
			    group by variant_id
			) reservation on reservation.variant_id = variant.id
			where variant.id in (:variantIds)
			""", nativeQuery = true)
	List<VariantAvailabilityProjection> findAvailabilityByVariantIds(
			@Param("variantIds") Collection<String> variantIds);
}
