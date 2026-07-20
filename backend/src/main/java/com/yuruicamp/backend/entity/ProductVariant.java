package com.yuruicamp.backend.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.math.BigDecimal;

@Entity
@Table(name = "product_variants")
public class ProductVariant {

    @Id
    @Column(name = "id", length = 64, nullable = false)
    private String id;

    @Column(name = "product_id", length = 32, nullable = false)
    private String productId;

    @Column(name = "sku", length = 64, nullable = false)
    private String sku;

    @Column(name = "price", precision = 12, scale = 2, nullable = false)
    private BigDecimal price;

    @Column(name = "specification", length = 200, nullable = false)
    private String specification;

    @Column(name = "status", length = 16, nullable = false)
    private String status;

    protected ProductVariant() {
    }
}
