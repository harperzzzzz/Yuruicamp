package com.yuruicamp.backend.order.domain;

import java.time.Instant;
import jakarta.persistence.*;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity @Table(name="order_status_history")
public class OrderStatusHistory {
	@Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
	@Column(name="order_id",nullable=false) private String orderId;
	@Enumerated(EnumType.STRING) @JdbcTypeCode(SqlTypes.NAMED_ENUM) @Column(nullable=false,columnDefinition="order_status") private OrderStatus status;
	@Column(name="occurred_at",nullable=false) private Instant occurredAt; @Column(name="actor_id") private String actorId; private String note;
	public static OrderStatusHistory of(String orderId,OrderStatus status,Instant occurredAt,String note){OrderStatusHistory history=new OrderStatusHistory();history.orderId=orderId;history.status=status;history.occurredAt=occurredAt;history.note=note;return history;}
}
