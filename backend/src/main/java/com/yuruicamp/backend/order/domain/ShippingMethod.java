package com.yuruicamp.backend.order.domain;

// 訂單的配送方式，名稱需與 PostgreSQL shipping_method 列舉一致。
public enum ShippingMethod {
	delivery,
	pickup
}
