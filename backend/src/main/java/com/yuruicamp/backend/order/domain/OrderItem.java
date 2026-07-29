package com.yuruicamp.backend.order.domain;

import java.math.BigDecimal;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

@Entity
@Table(name = "order_items")
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "product_id", nullable = false)
    private String productId;

    @Column(name = "variant_id", nullable = false)
    private String variantId;

    @Column(name = "sku_snapshot", nullable = false)
    private String sku;

    @Column(name = "product_name_snapshot", nullable = false)
    private String productName;

    @Column(name = "specification_snapshot", nullable = false)
    private String specification;

    @Column(name = "brand_name_snapshot", nullable = false)
    private String brandName;

    @Column(name = "image_url_snapshot")
    private String imageUrl;

    @Column(name = "unit_price_snapshot", nullable = false)
    private BigDecimal unitPrice;

    @Column(nullable = false)
    private int quantity;

    public Long getId() {
        return id;
    }

    public String getProductId() {
        return productId;
    }

    public String getVariantId() {
        return variantId;
    }

    public String getSku() {
        return sku;
    }

    public String getProductName() {
        return productName;
    }

    public String getSpecification() {
        return specification;
    }

    public String getBrandName() {
        return brandName;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public BigDecimal getUnitPrice() {
        return unitPrice;
    }

    public int getQuantity() {
        return quantity;
    }

    public static OrderItem snapshot(
            Order order,
            String productId,
            String variantId,
            String sku,
            String productName,
            String specification,
            String brandName,
            String imageUrl,
            BigDecimal unitPrice,
            int quantity) {
        OrderItem item = new OrderItem();

        item.order = order;
        item.productId = productId;
        item.variantId = variantId;
        item.sku = sku;
        item.productName = productName;
        item.specification = specification;
        item.brandName = brandName;
        item.imageUrl = imageUrl;
        item.unitPrice = unitPrice;
        item.quantity = quantity;

        return item;
    }
}
