package com.yuruicamp.backend.coupon.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.domain.PaymentMethod;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.TestConstructor;

@SpringBootTest
@EnabledIfEnvironmentVariable(named = "RUN_BACKEND_IT", matches = "true")
@TestConstructor(autowireMode = TestConstructor.AutowireMode.ALL)
// 使用真正 PostgreSQL 驗證領券 Trigger、資格與訂單套券快照。
class CouponPostgreSqlIntegrationTest {

	private final CouponService service;
	private final OrderRepository orders;
	private final JdbcTemplate jdbc;

	CouponPostgreSqlIntegrationTest(CouponService service, OrderRepository orders, JdbcTemplate jdbc) {
		this.service = service;
		this.orders = orders;
		this.jdbc = jdbc;
	}

	@BeforeEach
	void setUp() {
		cleanup();
		insertCustomer("CF001", "coupon-f1@example.com", false);
		insertCustomer("CF002", "coupon-f2@example.com", false);
	}

	@AfterEach
	void tearDown() {
		cleanup();
	}

	@Test
	void claimAllocatesCapacityAndAppearsInMyCoupons() {
		insertCoupon(99001L, "F-PROMO", "promotion", "fixed", "100.00", 2);

		var claim = service.claim("CF001", 99001L);

		assertThat(claim.status()).isEqualTo("claimed");
		assertThat(service.myCoupons("CF001")).hasSize(1);
		assertThat(service.publicCoupons().getFirst().claimedQuantity()).isEqualTo(1);
	}

	@Test
	void duplicateClaimIsRejectedWithoutIncreasingCounterTwice() {
		insertCoupon(99002L, "F-DUP", "promotion", "fixed", "50.00", 2);
		service.claim("CF001", 99002L);

		assertThatThrownBy(() -> service.claim("CF001", 99002L))
				.isInstanceOfSatisfying(BusinessException.class, ex ->
						assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.COUPON_ALREADY_CLAIMED));
		assertThat(jdbc.queryForObject("select claimed_quantity from coupons where id=99002", Integer.class))
				.isEqualTo(1);
	}

	@Test
	void capacityTriggerRejectsClaimAfterSoldOut() {
		insertCoupon(99003L, "F-SOLD", "promotion", "fixed", "50.00", 1);
		service.claim("CF001", 99003L);

		assertThatThrownBy(() -> service.claim("CF002", 99003L))
				.isInstanceOfSatisfying(BusinessException.class, ex ->
						assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.COUPON_SOLD_OUT));
	}

	@Test
	void checkoutUsesBackendDiscountAndKeepsClaimUnconsumed() {
		insertCoupon(99004L, "F-PERCENT", "promotion", "percent", "10.00", 2);
		Long claimId = service.claim("CF001", 99004L).id();
		Order order = new Order();
		order.initialize("OF99004", "CF001", "coupon-order", "coupon-hash",
				"Coupon Tester", "coupon-f1@example.com", "Tester", "Taipei", "0900000000",
				PaymentMethod.ecpay_credit, Instant.now(), Instant.now().plusSeconds(900));
		order.setPricing(new BigDecimal("1000.00"), BigDecimal.ZERO, BigDecimal.ZERO);
		orders.saveAndFlush(order);

		service.applyToOrder(order, "CF001", claimId, Instant.now());
		orders.flush();

		assertThat(order.getDiscount()).isEqualByComparingTo("100.00");
		assertThat(order.getTotal()).isEqualByComparingTo("900.00");
		assertThat(jdbc.queryForObject("select amount from order_coupons where order_id='OF99004'", BigDecimal.class))
				.isEqualByComparingTo("100.00");
		assertThat(jdbc.queryForObject("select status::text from coupon_claims where id=?", String.class, claimId))
				.isEqualTo("claimed");
	}

	@Test
	void firstPurchaseCouponRejectsUsedCustomer() {
		insertCustomer("CF001", "coupon-f1@example.com", true);
		insertCoupon(99005L, "F-FIRST", "firstPurchase", "fixed", "100.00", 2);

		assertThatThrownBy(() -> service.claim("CF001", 99005L))
				.isInstanceOfSatisfying(BusinessException.class, ex ->
						assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.COUPON_NOT_ELIGIBLE));
	}

	@Test
	void cancelledOrderDoesNotReturnOrConsumeClaim() {
		insertCoupon(99006L, "F-CANCEL", "promotion", "fixed", "100.00", 2);
		Long claimId = service.claim("CF001", 99006L).id();
		Order order = new Order();
		order.initialize("OF99006", "CF001", "coupon-cancel", "coupon-cancel-hash",
				"Coupon Tester", "coupon-f1@example.com", "Tester", "Taipei", "0900000000",
				PaymentMethod.ecpay_credit, Instant.now(), Instant.now().plusSeconds(900));
		order.setPricing(new BigDecimal("500.00"), BigDecimal.ZERO, BigDecimal.ZERO);
		orders.saveAndFlush(order);
		service.applyToOrder(order, "CF001", claimId, Instant.now());

		order.cancel();
		orders.saveAndFlush(order);

		assertThat(jdbc.queryForObject("select status::text from coupon_claims where id=?", String.class, claimId))
				.isEqualTo("claimed");
		assertThat(jdbc.queryForObject("select claimed_quantity from coupons where id=99006", Integer.class))
				.isEqualTo(1);
	}

	private void insertCustomer(String id, String email, boolean firstPurchaseUsed) {
		jdbc.update("""
				insert into customers (
				    id, name, phone, email, birthday, registered_at, points,
				    first_purchase_used, auth_provider, firebase_uid,
				    created_at, updated_at, status
				)
				values (?, 'Coupon Tester', '0900000000', ?, ?, now(), 0,
				        ?, 'google', ?, now(), now(), 'active')
				on conflict (id) do update set
				    email=excluded.email,
				    birthday=excluded.birthday,
				    first_purchase_used=excluded.first_purchase_used,
				    firebase_uid=excluded.firebase_uid,
				    status='active',
				    deleted_at=null,
				    updated_at=now()
				""", id, email, LocalDate.now().withDayOfMonth(1), firstPurchaseUsed, "firebase-" + id);
	}

	private void insertCoupon(Long id, String code, String category, String discountType,
			String discountValue, int issueQuantity) {
		jdbc.update("""
				insert into coupons (
				    id, code, name, discount_type, discount_value, minimum_amount,
				    issue_quantity, valid_from, valid_until, status, category
				)
				values (?, ?, 'Coupon Integration Test', ?, ?::numeric, 0,
				        ?, now() - interval '1 day', now() + interval '1 day', 'active', ?::coupon_category)
				""", id, code, discountType, discountValue, issueQuantity, category);
	}

	private void cleanup() {
		jdbc.update("delete from order_coupons where order_id like 'OF99%'");
		jdbc.update("delete from orders where id like 'OF99%'");
		jdbc.update("delete from coupon_claims where customer_id in ('CF001', 'CF002')");
		jdbc.update("delete from coupons where id between 99001 and 99099");
		jdbc.query("select soft_delete_customer(id) from customers where id in ('CF001', 'CF002')",
				resultSet -> {
				});
	}
}
