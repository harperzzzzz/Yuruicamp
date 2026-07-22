package com.yuruicamp.backend.catalog.infrastructure;

import com.yuruicamp.backend.catalog.domain.ProductCategory;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 商品分類主檔查詢入口，後台商品只接受已存在的分類 ID。
 */
public interface ProductCategoryRepository extends JpaRepository<ProductCategory, Long> {
}
