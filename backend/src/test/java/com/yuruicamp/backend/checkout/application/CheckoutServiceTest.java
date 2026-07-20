package com.yuruicamp.backend.checkout.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicReference;

import com.yuruicamp.backend.catalog.domain.EquipmentItem;
import com.yuruicamp.backend.catalog.domain.Product;
import com.yuruicamp.backend.catalog.domain.ProductVariant;
import com.yuruicamp.backend.catalog.infrastructure.EquipmentImageRepository;
import com.yuruicamp.backend.checkout.api.CheckoutCreateRequest;
import com.yuruicamp.backend.checkout.api.CheckoutSessionResponse;
import com.yuruicamp.backend.checkout.infrastructure.CheckoutProductRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import com.yuruicamp.backend.inventory.domain.InventoryStock;
import com.yuruicamp.backend.inventory.infrastructure.InventoryStockRepository;
import com.yuruicamp.backend.inventory.infrastructure.ProductStockReservationRepository;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.domain.OrderItem;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;
import com.yuruicamp.backend.order.infrastructure.OrderStatusHistoryRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

// 驗證建立結帳的冪等與空值處理。
class CheckoutServiceTest {

	private CustomerRepository customers;
	private CheckoutProductRepository products;
	private InventoryStockRepository stocks;
	private ProductStockReservationRepository reservations;
	private OrderRepository orders;
	private OrderStatusHistoryRepository histories;
	private EquipmentImageRepository images;
	private CheckoutService service;

	// 每個測試開始前建立乾淨的模擬元件。
	@BeforeEach
	void setUp() {
		customers = mock(CustomerRepository.class);
		products = mock(CheckoutProductRepository.class);
		stocks = mock(InventoryStockRepository.class);
		reservations = mock(ProductStockReservationRepository.class);
		orders = mock(OrderRepository.class);
		histories = mock(OrderStatusHistoryRepository.class);
		images = mock(EquipmentImageRepository.class);
		service = new CheckoutService(customers, products, stocks, reservations, orders, histories, images);
	}

	// 相同請求重送時應回傳原本的訂單。
	@Test
	void sameIdempotencyKeyReturnsOriginalCheckoutWithoutCreatingAgain() {
		AtomicReference<Order> savedOrder = arrangeSuccessfulCreation();
		CheckoutCreateRequest request = request("checkout-key-001", null);

		CheckoutSessionResponse first = service.create("C001", request);
		CheckoutSessionResponse replay = service.create("C001", request);

		assertThat(replay.orderId()).isEqualTo(first.orderId());
		assertThat(replay.shipping().recipientName()).isEqualTo("PENDING_CHECKOUT");
		assertThat(replay.shipping().phone()).isEqualTo("PENDING_CHECKOUT");
		assertThat(savedOrder.get().getCheckoutIdempotencyKey()).isEqualTo("checkout-key-001");
		assertThat(savedOrder.get().getCheckoutRequestHash()).hasSize(64);
		verify(orders).saveAndFlush(any(Order.class));
	}

	// 相同冪等鍵搭配不同內容時應回傳衝突。
	@Test
	void reusedIdempotencyKeyWithDifferentPayloadReturnsConflict() {
		arrangeSuccessfulCreation();
		service.create("C001", request("checkout-key-002", null));

		CheckoutCreateRequest changed = request("checkout-key-002",
				new CheckoutCreateRequest.Shipping("Amy", "0912345678", "台北市"));

		assertThatThrownBy(() -> service.create("C001", changed))
				.isInstanceOfSatisfying(BusinessException.class, ex ->
						assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.CONFLICT));
	}

	// 沒有冪等鍵時不應存取資料庫。
	@Test
	void missingIdempotencyKeyIsRejectedBeforeDatabaseAccess() {
		CheckoutCreateRequest request = request(" ", null);

		assertThatThrownBy(() -> service.create("C001", request))
				.isInstanceOfSatisfying(BusinessException.class, ex ->
						assertThat(ex.getErrorCode()).isEqualTo(ErrorCode.VALIDATION_ERROR));
		verify(customers, never()).findByIdForCheckout(any());
	}

	// 準備測試建立訂單需要的商品、庫存與會員資料。
	private AtomicReference<Order> arrangeSuccessfulCreation() {
		Customer customer = new Customer();
		customer.setId("C001");
		AtomicReference<Order> savedOrder = new AtomicReference<>();
		when(customers.findByIdForCheckout("C001")).thenReturn(Optional.of(customer));
		when(orders.findByCheckoutIdempotencyKey("C001", "checkout-key-001"))
				.thenAnswer(invocation -> Optional.ofNullable(savedOrder.get()));
		when(orders.findByCheckoutIdempotencyKey("C001", "checkout-key-002"))
				.thenAnswer(invocation -> Optional.ofNullable(savedOrder.get()));

		ProductVariant variant = mock(ProductVariant.class);
		Product product = mock(Product.class);
		EquipmentItem equipment = mock(EquipmentItem.class);
		InventoryStock stock = mock(InventoryStock.class);
		when(variant.getId()).thenReturn("V001");
		when(variant.getSku()).thenReturn("SKU-001");
		when(variant.getSpecification()).thenReturn("標準");
		when(variant.getPrice()).thenReturn(new BigDecimal("100.00"));
		when(variant.getProduct()).thenReturn(product);
		when(product.getId()).thenReturn("P001");
		when(product.getItem()).thenReturn(equipment);
		when(equipment.getId()).thenReturn("E001");
		when(equipment.getName()).thenReturn("測試商品");
		when(stock.getLocationId()).thenReturn("L001");
		when(stock.getOnHandQuantity()).thenReturn(10);
		when(products.findSellableById("V001")).thenReturn(Optional.of(variant));
		when(stocks.lockStoreStocksByVariantId("V001")).thenReturn(List.of(stock));
		when(reservations.activeQuantity("V001", "L001")).thenReturn(0);
		when(images.findByItemIdAndSortOrder("E001", 0)).thenReturn(Optional.empty());
		when(orders.saveAndFlush(any(Order.class))).thenAnswer(invocation -> {
			Order order = invocation.getArgument(0);
			long itemId = 1L;
			for (OrderItem item : order.getItems()) {
				ReflectionTestUtils.setField(item, "id", itemId++);
			}
			savedOrder.set(order);
			return order;
		});
		return savedOrder;
	}

	// 建立只有一項商品的測試請求。
	private static CheckoutCreateRequest request(String idempotencyKey,
			CheckoutCreateRequest.Shipping shipping) {
		return new CheckoutCreateRequest(
				List.of(new CheckoutCreateRequest.Item("V001", 1)),
				"ecpay-credit", shipping, idempotencyKey);
	}
}
