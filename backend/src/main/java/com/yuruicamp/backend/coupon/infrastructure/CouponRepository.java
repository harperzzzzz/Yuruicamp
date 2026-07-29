package com.yuruicamp.backend.coupon.infrastructure;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.yuruicamp.backend.coupon.domain.Coupon;
import com.yuruicamp.backend.coupon.domain.CouponStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import jakarta.persistence.LockModeType;

// 讀取有效優惠券，領券時使用悲觀鎖保護主檔狀態。
public interface CouponRepository extends JpaRepository<Coupon, Long> {

	@Query("select c from Coupon c where c.status=:status and c.validFrom<=:now and c.validUntil>=:now and c.claimedQuantity<c.issueQuantity order by c.validUntil asc, c.id asc")
	List<Coupon> findPublicCoupons(@Param("status") CouponStatus status, @Param("now") Instant now);

	@Lock(LockModeType.PESSIMISTIC_WRITE)
	@Query("select c from Coupon c where c.id=:id")
	Optional<Coupon> findByIdForClaim(@Param("id") Long id);
}
