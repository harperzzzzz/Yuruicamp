package com.yuruicamp.backend.order.infrastructure;

import java.util.List;
import java.util.Optional;
import com.yuruicamp.backend.order.domain.Order;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

// 讀取與儲存訂單資料。
public interface OrderRepository extends JpaRepository<Order,String> {

	// 取得會員的所有訂單。
	@Query("select distinct o from Order o left join fetch o.items where o.customerId=:customerId order by o.placedAt desc")
	List<Order> findAllForCustomer(@Param("customerId") String customerId);

	// 取得會員自己的指定訂單。
	@Query("select distinct o from Order o left join fetch o.items where o.id=:id and o.customerId=:customerId")
	Optional<Order> findForCustomer(@Param("id") String id, @Param("customerId") String customerId);

	// 使用會員與冪等鍵尋找已建立的訂單。
	@Query("select distinct o from Order o left join fetch o.items where o.customerId=:customerId and o.checkoutIdempotencyKey=:idempotencyKey")
	Optional<Order> findByCheckoutIdempotencyKey(@Param("customerId") String customerId,
			@Param("idempotencyKey") String idempotencyKey);
}
