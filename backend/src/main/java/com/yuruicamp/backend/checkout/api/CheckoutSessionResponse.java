package com.yuruicamp.backend.checkout.api;
import java.util.List;
public record CheckoutSessionResponse(String orderId,String paymentStatus,String paymentMethod,String status,String checkoutExpiresAt,Pricing pricing,List<Item> items,Shipping shipping,String checkoutStep) {
	public record Pricing(String subtotal,String shippingFee,String discount,String total) {}
	public record Item(long orderItemId,String productId,String variantId,String sku,String productName,String specification,String brandName,String imageUrl,String unitPrice,int quantity,String lineTotal) {}
	public record Shipping(String recipientName,String phone,String address) {}
}
