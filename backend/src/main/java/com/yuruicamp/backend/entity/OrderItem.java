package com.yuruicamp.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.math.BigDecimal;

@Entity
@Table(name = "order_items")
public class OrderItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "id", nullable = false)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Column(name = "product_id", length = 32, nullable = false)
    private String productId;

    @Column(name = "variant_id", length = 64, nullable = false)
    private String variantId;

    @Column(name = "sku_snapshot", length = 64, nullable = false)
    private String skuSnapshot;

    @Column(name = "product_name_snapshot", length = 200, nullable = false)
    private String productNameSnapshot;

    @Column(name = "specification_snapshot", length = 200, nullable = false)
    private String specificationSnapshot;

    @Column(name = "brand_name_snapshot", length = 120, nullable = false)
    private String brandNameSnapshot;

    @Column(name = "image_url_snapshot")
    private String imageUrlSnapshot;

    @Column(name = "unit_price_snapshot", precision = 12, scale = 2, nullable = false)
    private BigDecimal unitPriceSnapshot;

    @Column(name = "quantity", nullable = false)
    private int quantity;

    protected OrderItem() {
    }

    public OrderItem(String productId, String variantId, String skuSnapshot, String productNameSnapshot,
            String specificationSnapshot, String brandNameSnapshot, String imageUrlSnapshot,
            BigDecimal unitPriceSnapshot, int quantity) {
        this.productId = productId;
        this.variantId = variantId;
        this.skuSnapshot = skuSnapshot;
        this.productNameSnapshot = productNameSnapshot;
        this.specificationSnapshot = specificationSnapshot;
        this.brandNameSnapshot = brandNameSnapshot;
        this.imageUrlSnapshot = imageUrlSnapshot;
        this.unitPriceSnapshot = unitPriceSnapshot;
        this.quantity = quantity;
    }

    void assignOrder(Order order) {
        this.order = order;
    }
}
