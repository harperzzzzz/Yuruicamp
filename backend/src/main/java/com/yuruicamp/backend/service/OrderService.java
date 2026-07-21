package com.yuruicamp.backend.service;

import com.yuruicamp.backend.catalog.domain.ProductVariant;
import com.yuruicamp.backend.checkout.infrastructure.CheckoutProductRepository;
import com.yuruicamp.backend.dto.CreateOrderItemRequest;
import com.yuruicamp.backend.dto.CreateOrderRequest;
import com.yuruicamp.backend.dto.CreateOrderResponse;
import com.yuruicamp.backend.order.domain.Order;
import com.yuruicamp.backend.order.domain.OrderItem;
import com.yuruicamp.backend.order.domain.PaymentMethod;
import com.yuruicamp.backend.order.infrastructure.OrderRepository;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.format.DateTimeFormatter;
import java.time.ZoneOffset;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
// 供你自己端到端測試 ECPay 金流用的簡化建單流程；不經過 CheckoutService，僅共用 Order／ProductVariant 實體。
public class OrderService {

    private static final DateTimeFormatter ORDER_ID_FORMAT =
            DateTimeFormatter.ofPattern("'ORD'yyyyMMddHHmmssSSS").withZone(ZoneOffset.UTC);
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);

    private final OrderRepository orderRepository;
    private final CheckoutProductRepository productVariantRepository;

    public OrderService(OrderRepository orderRepository, CheckoutProductRepository productVariantRepository) {
        this.orderRepository = orderRepository;
        this.productVariantRepository = productVariantRepository;
    }

    @Transactional
    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        Instant now = Instant.now();
        PaymentMethod paymentMethod = normalizePaymentMethod(request.paymentMethod());
        Order order = new Order();
        order.initialize(
                nextOrderId(),
                request.customerId(),
                null,
                null,
                request.buyerName(),
                request.buyerEmail(),
                request.recipientName(),
                request.shippingAddress(),
                request.shippingPhone(),
                paymentMethod,
                now,
                null);

        BigDecimal subtotal = ZERO;
        for (CreateOrderItemRequest itemRequest : request.items()) {
            ProductVariant variant = productVariantRepository.findSellableById(itemRequest.variantId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Active product variant not found: " + itemRequest.variantId()));
            BigDecimal lineSubtotal = variant.getPrice().multiply(BigDecimal.valueOf(itemRequest.quantity()));
            subtotal = subtotal.add(lineSubtotal);
            String brandName = variant.getProduct().getItem().getBrand() == null
                    ? ""
                    : variant.getProduct().getItem().getBrand().getName();
            order.addItem(OrderItem.snapshot(
                    order,
                    variant.getProduct().getId(),
                    variant.getId(),
                    variant.getSku(),
                    variant.getProduct().getItem().getName(),
                    variant.getSpecification(),
                    brandName,
                    null,
                    variant.getPrice(),
                    itemRequest.quantity()));
        }

        order.setPricing(subtotal, ZERO, ZERO);
        Order saved = orderRepository.save(order);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public CreateOrderResponse getOrder(String orderId) {
        return orderRepository.findById(orderId)
                .map(this::toResponse)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found: " + orderId));
    }

    private PaymentMethod normalizePaymentMethod(String paymentMethod) {
        if (paymentMethod == null || paymentMethod.isBlank()) {
            return PaymentMethod.ecpay_credit;
        }
        String normalized = paymentMethod.trim().toLowerCase(Locale.ROOT).replace("-", "_");
        if (normalized.equals("cod")) {
            return PaymentMethod.cod;
        }
        if (normalized.equals("credit_card") || normalized.equals("ecpay_credit")) {
            return PaymentMethod.ecpay_credit;
        }
        try {
            return PaymentMethod.valueOf(normalized);
        } catch (IllegalArgumentException ex) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported paymentMethod: " + paymentMethod);
        }
    }

    private String nextOrderId() {
        return ORDER_ID_FORMAT.format(Instant.now());
    }

    private CreateOrderResponse toResponse(Order order) {
        return new CreateOrderResponse(
                order.getId(),
                order.getId(),
                order.getTotal(),
                order.getPaymentStatus().name().toUpperCase(Locale.ROOT)
        );
    }

}
