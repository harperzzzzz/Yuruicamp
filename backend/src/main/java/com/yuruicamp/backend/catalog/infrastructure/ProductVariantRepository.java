package com.yuruicamp.backend.catalog.infrastructure;

import java.util.List;

import com.yuruicamp.backend.catalog.domain.ProductVariant;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 商品規格寫入入口，更新時會保留已被交易引用的規格並改為停用。
 */
public interface ProductVariantRepository extends JpaRepository<ProductVariant, String> {

	List<ProductVariant> findAllByProductIdOrderById(String productId);

	boolean existsBySkuAndIdNot(String sku, String id);

	boolean existsBySku(String sku);
}
