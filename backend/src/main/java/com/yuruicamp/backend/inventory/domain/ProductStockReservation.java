package com.yuruicamp.backend.inventory.domain;

import java.time.Instant;
import jakarta.persistence.*;

@Entity @Table(name="product_stock_reservations")
public class ProductStockReservation {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
	@Column(name="order_item_id",nullable=false) private Long orderItemId;
	@Column(name="variant_id",nullable=false) private String variantId;
	@Column(name="location_id",nullable=false) private String locationId;
	@Column(nullable=false) private int quantity;
	@Column(nullable=false) private String status;
	@Column(name="idempotency_key",nullable=false,unique=true) private String idempotencyKey;
	@Column(name="reserved_at",nullable=false) private Instant reservedAt;
	@Column(name="expires_at") private Instant expiresAt;
	@Column(name="released_at") private Instant releasedAt;
	@Column(name="fulfilled_at") private Instant fulfilledAt;
	@Column(name="inventory_domain",nullable=false) private String inventoryDomain;
	public static ProductStockReservation active(Long orderItemId,String variantId,String locationId,int quantity,String idempotencyKey,Instant now,Instant expiresAt){ProductStockReservation r=new ProductStockReservation();r.orderItemId=orderItemId;r.variantId=variantId;r.locationId=locationId;r.quantity=quantity;r.status="active";r.idempotencyKey=idempotencyKey;r.reservedAt=now;r.expiresAt=expiresAt;r.inventoryDomain="store";return r;}
	public void release(String nextStatus, Instant now){if("active".equals(status)){status=nextStatus;releasedAt=now;}}
	public String getStatus(){return status;} public Instant getExpiresAt(){return expiresAt;} public String getVariantId(){return variantId;} public String getLocationId(){return locationId;} public int getQuantity(){return quantity;}
}
