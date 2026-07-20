package com.yuruicamp.backend.order.infrastructure;
import com.yuruicamp.backend.order.domain.OrderStatusHistory;
import org.springframework.data.jpa.repository.JpaRepository;
public interface OrderStatusHistoryRepository extends JpaRepository<OrderStatusHistory,Long> {}
