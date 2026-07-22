package com.yuruicamp.backend.catalog.infrastructure;

import java.util.List;
import java.util.Optional;
import java.math.BigDecimal;

import com.yuruicamp.backend.catalog.domain.Product;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

/**
 * Product reads for public catalog.
 * 公開商品讀取；用 JOIN FETCH 避免 open-in-view=false 時 Lazy 爆炸。
 */
public interface ProductRepository extends JpaRepository<Product, String> {

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select p from Product p join fetch p.item where p.id = :id")
	Optional<Product> findByIdForUpdate(@Param("id") String id);

	/**
	 * Pagination phase 1: page only IDs. Fetch-joining variants here would
	 * duplicate product rows and make SQL pagination unreliable.
	 */
	@Query(value = """
			select p.id from Product p
			join p.item i
			left join i.category category
			left join i.brand brand
			where p.status = 'active'
			  and i.active = true
			  and (:category = '' or lower(category.name) = lower(:category))
			  and (:brand = '' or lower(brand.name) = lower(:brand))
			  and exists (select v.id from ProductVariant v where v.product = p and v.status = 'active')
			  and exists (
			      select priced.id from ProductVariant priced
			      where priced.product = p
			        and priced.status = 'active'
			        and priced.price >= :minPrice
			        and priced.price <= :maxPrice
			  )
			""", countQuery = """
			select count(p) from Product p
			join p.item i
			left join i.category category
			left join i.brand brand
			where p.status = 'active'
			  and i.active = true
			  and (:category = '' or lower(category.name) = lower(:category))
			  and (:brand = '' or lower(brand.name) = lower(:brand))
			  and exists (select v.id from ProductVariant v where v.product = p and v.status = 'active')
			  and exists (
			      select priced.id from ProductVariant priced
			      where priced.product = p
			        and priced.status = 'active'
			        and priced.price >= :minPrice
			        and priced.price <= :maxPrice
			  )
			""")
	Page<String> findActiveIdsForCatalog(
			@Param("category") String category,
			@Param("brand") String brand,
			@Param("minPrice") BigDecimal minPrice,
			@Param("maxPrice") BigDecimal maxPrice,
			Pageable pageable);

	/** Pagination phase 2: load complete relations for the IDs in one page. */
	@Query("""
			select distinct p from Product p
			join fetch p.item i
			left join fetch i.brand
			left join fetch i.category
			left join fetch p.variants v
			where p.id in :ids
			""")
	List<Product> findAllByIdInForCatalog(@Param("ids") List<String> ids);

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
