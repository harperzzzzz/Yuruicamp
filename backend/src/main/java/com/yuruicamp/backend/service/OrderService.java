package com.yuruicamp.backend.service;

import com.yuruicamp.backend.dto.CreateOrderItemRequest;
import com.yuruicamp.backend.dto.CreateOrderRequest;
import com.yuruicamp.backend.dto.CreateOrderResponse;
import com.yuruicamp.backend.entity.Order;
import com.yuruicamp.backend.entity.OrderItem;
import com.yuruicamp.backend.repository.OrderRepository;
import com.yuruicamp.backend.repository.ProductVariantRepository;
import com.yuruicamp.backend.repository.ProductVariantRepository.CatalogVariantView;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;

@Service
public class OrderService {

    private static final DateTimeFormatter ORDER_ID_FORMAT =
            DateTimeFormatter.ofPattern("'ORD'yyyyMMddHHmmssSSS").withZone(ZoneOffset.UTC);
    private static final BigDecimal ZERO = BigDecimal.ZERO.setScale(2);

    private final OrderRepository orderRepository;
    private final ProductVariantRepository productVariantRepository;

    public OrderService(OrderRepository orderRepository, ProductVariantRepository productVariantRepository) {
        this.orderRepository = orderRepository;
        this.productVariantRepository = productVariantRepository;
    }

    @Transactional
    public CreateOrderResponse createOrder(CreateOrderRequest request) {
        OffsetDateTime now = OffsetDateTime.now(ZoneOffset.UTC);
        BigDecimal subtotal = ZERO;
        String paymentMethod = normalizePaymentMethod(request.paymentMethod());
        Order order = new Order(
                nextOrderId(now),
                request.customerId(),
                request.buyerName(),
                request.buyerEmail(),
                request.recipientName(),
                request.shippingAddress(),
                request.shippingPhone(),
                ZERO,
                ZERO,
                ZERO,
                ZERO,
                paymentMethod,
                "unpaid",
                "none",
                "unshipped",
                now,
                now,
                now
        );

        for (CreateOrderItemRequest itemRequest : request.items()) {
            CatalogVariantView variant = productVariantRepository.findActiveCatalogVariant(itemRequest.variantId())
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST,
                            "Active product variant not found: " + itemRequest.variantId()));
            BigDecimal lineSubtotal = variant.getPrice().multiply(BigDecimal.valueOf(itemRequest.quantity()));
            subtotal = subtotal.add(lineSubtotal);
            order.addItem(new OrderItem(
                    variant.getProductId(),
                    variant.getVariantId(),
                    variant.getSku(),
                    variant.getProductName(),
                    variant.getSpecification(),
                    variant.getBrandName(),
                    null,
                    variant.getPrice(),
                    itemRequest.quantity()
            ));
        }

        order.updateTotals(subtotal, ZERO, ZERO);
        Order saved = orderRepository.save(order);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public CreateOrderResponse getOrder(String orderId) {
        return orderRepository.findById(orderId)
                .map(this::toResponse)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Order not found: " + orderId));
    }

    private String normalizePaymentMethod(String paymentMethod) {
        if (paymentMethod == null || paymentMethod.isBlank()) {
            return "cod";
        }
        String normalized = paymentMethod.trim().toLowerCase(Locale.ROOT).replace("_", "-");
        if (!normalized.equals("cod") && !normalized.equals("credit-card") && !normalized.equals("line-pay")) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Unsupported paymentMethod: " + paymentMethod);
        }
        return normalized;
    }

    private String nextOrderId(OffsetDateTime now) {
        return ORDER_ID_FORMAT.format(now);
    }

    private CreateOrderResponse toResponse(Order order) {
        return new CreateOrderResponse(
                order.getId(),
                order.getId(),
                order.getTotal(),
                order.getPaymentStatus().toUpperCase(Locale.ROOT)
        );
    }

}
