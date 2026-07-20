package com.yuruicamp.backend.checkout.application;

import java.math.*;
import java.time.*;
import java.util.*;
import com.yuruicamp.backend.catalog.domain.*;
import com.yuruicamp.backend.catalog.infrastructure.EquipmentImageRepository;
import com.yuruicamp.backend.checkout.api.*;
import com.yuruicamp.backend.checkout.infrastructure.CheckoutProductRepository;
import com.yuruicamp.backend.common.exception.*;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import com.yuruicamp.backend.inventory.domain.*;
import com.yuruicamp.backend.inventory.infrastructure.*;
import com.yuruicamp.backend.order.domain.*;
import com.yuruicamp.backend.order.infrastructure.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class CheckoutService {
	private static final Duration HOLD = Duration.ofMinutes(15);
	private static final String PENDING = "PENDING_CHECKOUT";
	private final CustomerRepository customers; private final CheckoutProductRepository products; private final InventoryStockRepository stocks; private final ProductStockReservationRepository reservations; private final OrderRepository orders; private final OrderStatusHistoryRepository histories; private final EquipmentImageRepository images;
	public CheckoutService(CustomerRepository customers,CheckoutProductRepository products,InventoryStockRepository stocks,ProductStockReservationRepository reservations,OrderRepository orders,OrderStatusHistoryRepository histories,EquipmentImageRepository images){this.customers=customers;this.products=products;this.stocks=stocks;this.reservations=reservations;this.orders=orders;this.histories=histories;this.images=images;}

	@Transactional
	public CheckoutSessionResponse create(String customerId, CheckoutCreateRequest request) {
		Customer customer=customers.findById(customerId).orElseThrow(()->new BusinessException(ErrorCode.UNAUTHORIZED,"Customer not found"));
		Map<String,Integer> requested=new LinkedHashMap<>(); for(var item:request.items()) requested.merge(item.variantId(),item.quantity(),Integer::sum);
		Instant now=Instant.now(), expires=now.plus(HOLD); PaymentMethod paymentMethod=parsePaymentMethod(request.paymentMethod());
		CheckoutCreateRequest.Shipping shipping=request.shipping(); String recipient=nonBlank(shipping==null?null:shipping.recipientName(),customer.getName()); String phone=nonBlank(shipping==null?null:shipping.phone(),customer.getPhone()); String address=nonBlank(shipping==null?null:shipping.address(),PENDING);
		Order order=new Order(); order.initialize(newOrderId(),customerId,nonBlank(customer.getName(),PENDING),nonBlank(customer.getEmail(),PENDING),recipient,address,phone,paymentMethod,now,expires);
		BigDecimal subtotal=BigDecimal.ZERO; List<ReservationDraft> reserveDrafts=new ArrayList<>();
		for(var entry:requested.entrySet()) {
			ProductVariant variant=products.findSellableById(entry.getKey()).orElseThrow(()->new BusinessException(ErrorCode.VARIANT_NOT_SELLABLE,"Variant not sellable: "+entry.getKey()));
			InventoryStock stock=selectAvailableStock(variant.getId(),entry.getValue());
			EquipmentItem equipment=variant.getProduct().getItem(); String brand=equipment.getBrand()==null?"":equipment.getBrand().getName(); String image=images.findByItemIdAndSortOrder(equipment.getId(),0).map(EquipmentImage::getUrl).orElse(null);
			OrderItem orderItem=OrderItem.snapshot(order,variant.getProduct().getId(),variant.getId(),variant.getSku(),equipment.getName(),variant.getSpecification(),brand,image,variant.getPrice(),entry.getValue()); order.addItem(orderItem); subtotal=subtotal.add(variant.getPrice().multiply(BigDecimal.valueOf(entry.getValue()))); reserveDrafts.add(new ReservationDraft(variant.getId(),stock.getLocationId(),entry.getValue()));
		}
		order.setPricing(subtotal,BigDecimal.ZERO,BigDecimal.ZERO); Order saved=orders.saveAndFlush(order);
		for(int i=0;i<saved.getItems().size();i++){OrderItem item=saved.getItems().get(i);ReservationDraft draft=reserveDrafts.get(i);reservations.save(ProductStockReservation.active(item.getId(),draft.variantId(),draft.locationId(),draft.quantity(),saved.getId()+":"+item.getId(),now,expires));}
		histories.save(OrderStatusHistory.of(saved.getId(),OrderStatus.unshipped,now,"Checkout draft created")); return toResponse(saved);
	}

	@Transactional
	public CheckoutSessionResponse cancel(String customerId,String orderId){Order order=orders.findForCustomer(orderId,customerId).orElseThrow(()->new BusinessException(ErrorCode.FORBIDDEN,"Order not found or not owned by customer")); if(order.getPaymentStatus()!=PaymentStatus.unpaid)throw new BusinessException(ErrorCode.CONFLICT,"Paid order cannot be cancelled here"); Instant now=Instant.now(); order.cancel(); reservations.findActiveByOrderItemIdIn(order.getItems().stream().map(OrderItem::getId).toList()).forEach(r->r.release("released",now)); histories.save(OrderStatusHistory.of(orderId,OrderStatus.cancelled,now,"Cancelled by customer")); return toResponse(order); }

	private InventoryStock selectAvailableStock(String variantId,int requested){for(InventoryStock stock:stocks.lockStoreStocksByVariantId(variantId)){if(stock.getOnHandQuantity()-reservations.activeQuantity(variantId,stock.getLocationId())>=requested)return stock;}throw new BusinessException(ErrorCode.STOCK_INSUFFICIENT,"Insufficient stock for variant: "+variantId);}
	private static String nonBlank(String value,String fallback){return value==null||value.isBlank()?fallback:value;}
	private static PaymentMethod parsePaymentMethod(String raw){if(raw==null||raw.isBlank())return PaymentMethod.ecpay_credit;try{return PaymentMethod.valueOf(raw.replace('-','_'));}catch(IllegalArgumentException ex){throw new BusinessException(ErrorCode.VALIDATION_ERROR,"Unsupported paymentMethod: "+raw);}}
	private static String newOrderId(){return "O"+UUID.randomUUID().toString().replace("-","").substring(0,31);}
	private static String money(BigDecimal value){return value.setScale(2,RoundingMode.HALF_UP).toPlainString();}
	private static CheckoutSessionResponse toResponse(Order order){var items=order.getItems().stream().map(item->new CheckoutSessionResponse.Item(item.getId(),item.getProductId(),item.getVariantId(),item.getSku(),item.getProductName(),item.getSpecification(),item.getBrandName(),item.getImageUrl(),money(item.getUnitPrice()),item.getQuantity(),money(item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity()))))).toList();var shipping=new CheckoutSessionResponse.Shipping(order.getRecipientName(),order.getShippingPhone(),order.getShippingAddress());var pricing=new CheckoutSessionResponse.Pricing(money(order.getSubtotal()),money(order.getShippingFee()),money(order.getDiscount()),money(order.getTotal()));boolean ready=!PENDING.equals(order.getRecipientName())&&!PENDING.equals(order.getShippingPhone())&&!PENDING.equals(order.getShippingAddress());return new CheckoutSessionResponse(order.getId(),order.getPaymentStatus().name(),order.getPaymentMethod().name().replace('_','-'),order.getStatus().name(),order.getCheckoutExpiresAt().toString(),pricing,items,shipping,ready?"ready_to_pay":"draft");}
	private record ReservationDraft(String variantId,String locationId,int quantity){}
}
