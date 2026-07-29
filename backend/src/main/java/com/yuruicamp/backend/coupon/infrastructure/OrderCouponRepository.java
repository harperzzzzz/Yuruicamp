package com.yuruicamp.backend.coupon.infrastructure;

import java.util.Optional;

import com.yuruicamp.backend.coupon.domain.OrderCoupon;
import org.springframework.data.jpa.repository.JpaRepository;

// 讀寫一張訂單唯一使用的優惠券快照。
public interface OrderCouponRepository extends JpaRepository<OrderCoupon, Long> {

	Optional<OrderCoupon> findByOrderId(String orderId);

	void deleteByOrderId(String orderId);
}
