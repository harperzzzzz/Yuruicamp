package com.yuruicamp.backend.checkout.application;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.yuruicamp.backend.catalog.domain.EquipmentImage;
import com.yuruicamp.backend.catalog.domain.EquipmentItem;
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
import com.yuruicamp.backend.inventory.domain.ProductStockReservation;
import com.yuruicamp.backend.inventory.infrastructure.InventoryStockRepository;
import com.yuruicamp.backend.inventory.infrastructure.ProductStockReservationRepository;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.domain.OrderItem;
import com.yuruicamp.backend.order.domain.OrderStatus;
import com.yuruicamp.backend.order.domain.OrderStatusHistory;
import com.yuruicamp.backend.order.domain.PaymentMethod;
import com.yuruicamp.backend.order.domain.PaymentStatus;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;
import com.yuruicamp.backend.order.infrastructure.OrderStatusHistoryRepository;

@Service
// 處理建立結帳、取消訂單與保留庫存。
public class CheckoutService {
	private static final Duration HOLD = Duration.ofMinutes(15);
	private static final String PENDING = "PENDING_CHECKOUT";
	private final CustomerRepository customers;
	private final CheckoutProductRepository products;
	private final InventoryStockRepository stocks;
	private final ProductStockReservationRepository reservations;
	private final OrderRepository orders;
	private final OrderStatusHistoryRepository histories;
	private final EquipmentImageRepository images;

	// 準備建立與取消結帳需要使用的資料庫元件。
	public CheckoutService(CustomerRepository customers, CheckoutProductRepository products,
			InventoryStockRepository stocks, ProductStockReservationRepository reservations,
			OrderRepository orders, OrderStatusHistoryRepository histories,
			EquipmentImageRepository images) {
		this.customers = customers;
		this.products = products;
		this.stocks = stocks;
		this.reservations = reservations;
		this.orders = orders;
		this.histories = histories;
		this.images = images;
	}

	// 建立待付款訂單，並保留商品庫存 15 分鐘。
	@Transactional
	public CheckoutSessionResponse create(String customerId, CheckoutCreateRequest request) {
		validateCreateInput(customerId, request);
		String idempotencyKey = request.idempotencyKey().trim();
		Map<String, Integer> requested = mergeRequestedItems(request.items());
		PaymentMethod paymentMethod = parsePaymentMethod(request.paymentMethod());
		String requestHash = fingerprint(requested, paymentMethod, request.shipping());

		Customer customer = customers.findByIdForCheckout(customerId)
				.orElseThrow(() -> new BusinessException(ErrorCode.UNAUTHORIZED, "Customer not found"));
		Optional<Order> replay = orders.findByCheckoutIdempotencyKey(customerId, idempotencyKey);
		if (replay.isPresent()) {
			Order existing = replay.get();
			if (!requestHash.equals(existing.getCheckoutRequestHash())) {
				throw new BusinessException(ErrorCode.CONFLICT,
						"Idempotency key was already used with a different checkout request");
			}
			return toResponse(existing);
		}

		Instant now = Instant.now();
		Instant expires = now.plus(HOLD);
		CheckoutCreateRequest.Shipping shipping = request.shipping();
		String recipient = firstNonBlank(shipping == null ? null : shipping.recipientName(), customer.getName(), PENDING);
		String phone = firstNonBlank(shipping == null ? null : shipping.phone(), customer.getPhone(), PENDING);
		String address = firstNonBlank(shipping == null ? null : shipping.address(), PENDING);
		Order order = new Order();
		order.initialize(newOrderId(), customerId, idempotencyKey, requestHash,
				firstNonBlank(customer.getName(), PENDING), firstNonBlank(customer.getEmail(), PENDING),
				recipient, address, phone, paymentMethod, now, expires);
		BigDecimal subtotal = BigDecimal.ZERO;
		List<ReservationDraft> reserveDrafts = new ArrayList<>();

		for (var entry : requested.entrySet()) {
			ProductVariant variant = products.findSellableById(entry.getKey())
					.orElseThrow(() -> new BusinessException(ErrorCode.VARIANT_NOT_SELLABLE,
							"Variant not sellable: " + entry.getKey()));
			InventoryStock stock = selectAvailableStock(variant.getId(), entry.getValue());
			EquipmentItem equipment = variant.getProduct().getItem();
			String brand = equipment.getBrand() == null ? "" : equipment.getBrand().getName();
			String image = images.findByItemIdAndSortOrder(equipment.getId(), 0)
					.map(EquipmentImage::getUrl)
					.orElse(null);
			OrderItem orderItem = OrderItem.snapshot(order, variant.getProduct().getId(), variant.getId(),
					variant.getSku(), equipment.getName(), variant.getSpecification(), brand, image,
					variant.getPrice(), entry.getValue());

			order.addItem(orderItem);
			subtotal = subtotal.add(variant.getPrice().multiply(BigDecimal.valueOf(entry.getValue())));
			reserveDrafts.add(new ReservationDraft(variant.getId(), stock.getLocationId(), entry.getValue()));
		}

		order.setPricing(subtotal, BigDecimal.ZERO, BigDecimal.ZERO);
		Order saved = orders.saveAndFlush(order);

		for (int i = 0; i < saved.getItems().size(); i++) {
			OrderItem item = saved.getItems().get(i);
			ReservationDraft draft = reserveDrafts.get(i);
			reservations.save(ProductStockReservation.active(item.getId(), draft.variantId(),
					draft.locationId(), draft.quantity(), saved.getId() + ":" + item.getId(), now, expires));
		}

		histories.save(OrderStatusHistory.of(saved.getId(), OrderStatus.unshipped, now,
				"Checkout draft created"));

		return toResponse(saved);
	}

	// 取消會員自己的未付款訂單，並釋放庫存。
	@Transactional
	public CheckoutSessionResponse cancel(String customerId, String orderId) {
		Order order = orders.findForCustomer(orderId, customerId)
				.orElseThrow(() -> new BusinessException(ErrorCode.FORBIDDEN,
						"Order not found or not owned by customer"));

		if (order.getPaymentStatus() != PaymentStatus.unpaid) {
			throw new BusinessException(ErrorCode.CONFLICT, "Paid order cannot be cancelled here");
		}

		Instant now = Instant.now();
		order.cancel();
		reservations.findActiveByOrderItemIdIn(order.getItems().stream().map(OrderItem::getId).toList())
				.forEach(reservation -> reservation.release("released", now));
		histories.save(OrderStatusHistory.of(orderId, OrderStatus.cancelled, now, "Cancelled by customer"));

		return toResponse(order);
	}

	// 找出庫存足夠的門市庫位。
	private InventoryStock selectAvailableStock(String variantId, int requested) {
		for (InventoryStock stock : stocks.lockStoreStocksByVariantId(variantId)) {
			if (stock.getOnHandQuantity() - reservations.activeQuantity(variantId, stock.getLocationId()) >= requested) {
				return stock;
			}
		}

		throw new BusinessException(ErrorCode.STOCK_INSUFFICIENT,
				"Insufficient stock for variant: " + variantId);
	}

	// 檢查會員、商品與冪等鍵是否有填寫。
	private static void validateCreateInput(String customerId, CheckoutCreateRequest request) {
		if (customerId == null || customerId.isBlank() || request == null
				|| request.items() == null || request.items().isEmpty()
				|| request.idempotencyKey() == null || request.idempotencyKey().isBlank()) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR,
					"customerId, items and idempotencyKey are required");
		}
		if (request.idempotencyKey().trim().length() > 128) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "idempotencyKey must not exceed 128 characters");
		}
		for (CheckoutCreateRequest.Item item : request.items()) {
			if (item == null || item.variantId() == null || item.variantId().isBlank() || item.quantity() < 1) {
				throw new BusinessException(ErrorCode.VALIDATION_ERROR,
						"Each checkout item requires variantId and a positive quantity");
			}
		}
	}

	// 合併相同規格的數量，並固定商品順序。
	private static Map<String, Integer> mergeRequestedItems(List<CheckoutCreateRequest.Item> items) {
		Map<String, Integer> requested = new TreeMap<>();
		try {
			for (CheckoutCreateRequest.Item item : items) {
				requested.merge(item.variantId().trim(), item.quantity(), Math::addExact);
			}
		}
		catch (ArithmeticException ex) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Checkout item quantity is too large");
		}
		return requested;
	}

	// 取得第一個有內容的文字，全部空白時使用草稿佔位文字。
	private static String firstNonBlank(String... values) {
		for (String value : values) {
			if (value != null && !value.isBlank()) {
				return value.trim();
			}
		}
		return PENDING;
	}

	// 產生請求指紋，用來判斷相同冪等鍵的內容是否一致。
	private static String fingerprint(Map<String, Integer> items, PaymentMethod paymentMethod,
			CheckoutCreateRequest.Shipping shipping) {
		StringBuilder canonical = new StringBuilder();
		appendCanonical(canonical, paymentMethod.name());
		appendCanonical(canonical, shipping == null ? null : shipping.recipientName());
		appendCanonical(canonical, shipping == null ? null : shipping.phone());
		appendCanonical(canonical, shipping == null ? null : shipping.address());
		items.forEach((variantId, quantity) -> {
			appendCanonical(canonical, variantId);
			appendCanonical(canonical, String.valueOf(quantity));
		});
		try {
			byte[] digest = MessageDigest.getInstance("SHA-256")
					.digest(canonical.toString().getBytes(StandardCharsets.UTF_8));
			return HexFormat.of().formatHex(digest);
		}
		catch (NoSuchAlgorithmException ex) {
			throw new IllegalStateException("SHA-256 is not available", ex);
		}
	}

	// 加入欄位長度，避免不同資料組合出相同內容。
	private static void appendCanonical(StringBuilder target, String value) {
		String normalized = value == null ? "" : value.trim();
		target.append(normalized.length()).append(':').append(normalized).append('|');
	}

	// 將 API 的付款方式文字轉成後端列舉值。
	private static PaymentMethod parsePaymentMethod(String raw) {
		if (raw == null || raw.isBlank()) {
			return PaymentMethod.ecpay_credit;
		}
		try {
			return PaymentMethod.valueOf(raw.replace('-', '_'));
		}
		catch (IllegalArgumentException ex) {
			throw new BusinessException(ErrorCode.VALIDATION_ERROR, "Unsupported paymentMethod: " + raw);
		}
	}

	// 產生符合資料庫長度的訂單編號。
	private static String newOrderId() {
		return "O" + UUID.randomUUID().toString().replace("-", "").substring(0, 31);
	}

	// 將金額轉成兩位小數文字。
	private static String money(BigDecimal value) {
		return value.setScale(2, RoundingMode.HALF_UP).toPlainString();
	}

	// 將訂單資料轉成前端需要的結帳回應。
	private static CheckoutSessionResponse toResponse(Order order) {
		var items = order.getItems().stream()
				.map(item -> new CheckoutSessionResponse.Item(item.getId(), item.getProductId(),
						item.getVariantId(), item.getSku(), item.getProductName(), item.getSpecification(),
						item.getBrandName(), item.getImageUrl(), money(item.getUnitPrice()), item.getQuantity(),
						money(item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))))
				.toList();
		var shipping = new CheckoutSessionResponse.Shipping(order.getRecipientName(),
				order.getShippingPhone(), order.getShippingAddress());
		var pricing = new CheckoutSessionResponse.Pricing(money(order.getSubtotal()),
				money(order.getShippingFee()), money(order.getDiscount()), money(order.getTotal()));
		boolean ready = !PENDING.equals(order.getRecipientName())
				&& !PENDING.equals(order.getShippingPhone())
				&& !PENDING.equals(order.getShippingAddress());
		return new CheckoutSessionResponse(order.getId(), order.getPaymentStatus().name(),
				order.getPaymentMethod().name().replace('_', '-'), order.getStatus().name(),
				order.getCheckoutExpiresAt().toString(), pricing, items, shipping,
				ready ? "ready_to_pay" : "draft");
	}

	// 暫存建立庫存保留紀錄需要的資料。
	private record ReservationDraft(String variantId, String locationId, int quantity) {
	}
}
