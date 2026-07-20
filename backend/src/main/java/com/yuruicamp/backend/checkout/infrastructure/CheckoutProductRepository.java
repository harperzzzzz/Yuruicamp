package com.yuruicamp.backend.checkout.infrastructure;
import java.util.Optional;
import com.yuruicamp.backend.catalog.domain.ProductVariant;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
public interface CheckoutProductRepository extends JpaRepository<ProductVariant,String> {
	@Query("select v from ProductVariant v join fetch v.product p join fetch p.item i left join fetch i.brand where v.id=:id and v.status='active' and p.status='active' and i.active=true") Optional<ProductVariant> findSellableById(@Param("id") String id);
}
