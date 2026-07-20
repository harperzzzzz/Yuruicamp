package com.yuruicamp.backend.inventory.domain;

import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;
import jakarta.persistence.*;

@Entity @Table(name="inventory_stocks") @IdClass(InventoryStock.Key.class)
public class InventoryStock {
	@Id @Column(name="location_id") private String locationId;
	@Id @Column(name="variant_id") private String variantId;
	@Column(name="on_hand_quantity",nullable=false) private int onHandQuantity;
	@Column(name="inventory_domain",nullable=false) private String inventoryDomain;
	@Column(name="updated_at",nullable=false) private Instant updatedAt;
	public String getLocationId(){return locationId;} public String getVariantId(){return variantId;} public int getOnHandQuantity(){return onHandQuantity;}
	public static class Key implements Serializable { private String locationId; private String variantId; public Key(){} @Override public boolean equals(Object o){return o instanceof Key key&&Objects.equals(locationId,key.locationId)&&Objects.equals(variantId,key.variantId);} @Override public int hashCode(){return Objects.hash(locationId,variantId);} }
}
