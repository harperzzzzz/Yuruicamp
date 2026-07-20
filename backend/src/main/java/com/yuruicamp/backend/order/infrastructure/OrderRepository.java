package com.yuruicamp.backend.order.infrastructure;

import java.util.List;
import java.util.Optional;
import com.yuruicamp.backend.order.domain.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface OrderRepository extends JpaRepository<Order,String> {
	@Query("select distinct o from Order o left join fetch o.items where o.customerId=:customerId order by o.placedAt desc") List<Order> findAllForCustomer(@Param("customerId") String customerId);
	@Query("select distinct o from Order o left join fetch o.items where o.id=:id and o.customerId=:customerId") Optional<Order> findForCustomer(@Param("id") String id,@Param("customerId") String customerId);
}
