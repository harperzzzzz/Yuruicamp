package com.yuruicamp.backend.repository;

import com.yuruicamp.backend.entity.ProductVariant;
import java.math.BigDecimal;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ProductVariantRepository extends JpaRepository<ProductVariant, String> {

    @Query(value = """
            SELECT pv.id AS variantId,
                   pv.product_id AS productId,
                   pv.sku AS sku,
                   pv.price AS price,
                   pv.specification AS specification,
                   ei.name AS productName,
                   COALESCE(b.name, '') AS brandName
              FROM product_variants pv
              JOIN products p ON p.id = pv.product_id
              JOIN equipment_items ei ON ei.id = p.item_id
              LEFT JOIN brands b ON b.id = ei.brand_id
             WHERE pv.id = :variantId
               AND pv.status = 'active'
               AND p.status = 'active'
               AND ei.active = true
            """, nativeQuery = true)
    Optional<CatalogVariantView> findActiveCatalogVariant(@Param("variantId") String variantId);

    interface CatalogVariantView {
        String getVariantId();

        String getProductId();

        String getSku();

        BigDecimal getPrice();

        String getSpecification();

        String getProductName();

        String getBrandName();
    }
}
