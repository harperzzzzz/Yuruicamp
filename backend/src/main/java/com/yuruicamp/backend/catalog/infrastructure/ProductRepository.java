package com.yuruicamp.backend.catalog.infrastructure;

import java.util.List;
import java.util.Optional;

import com.yuruicamp.backend.catalog.domain.Product;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * Product reads for public catalog.
 * 公開商品讀取；用 JOIN FETCH 避免 open-in-view=false 時 Lazy 爆炸。
 */
public interface ProductRepository extends JpaRepository<Product, String> {

	/**
	 * Active products whose equipment item is active, with item/brand/category/variants loaded.
	 */
	@Query("""
			select distinct p from Product p
			join fetch p.item i
			left join fetch i.brand
			left join fetch i.category
			left join fetch p.variants v
			where p.status = 'active'
			  and i.active = true
			""")
	List<Product> findAllActiveForCatalog();

	@Query("""
			select distinct p from Product p
			join fetch p.item i
			left join fetch i.brand
			left join fetch i.category
			left join fetch p.variants v
			where p.id = :id
			  and p.status = 'active'
			  and i.active = true
			""")
	Optional<Product> findActiveByIdForCatalog(@Param("id") String id);
}
