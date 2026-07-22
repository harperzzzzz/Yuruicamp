package com.yuruicamp.backend.order.domain;

import java.time.Instant;

import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "order_status_history")
public class OrderStatusHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "order_id", nullable = false)
    private String orderId;

    @Enumerated(EnumType.STRING)
    @JdbcTypeCode(SqlTypes.NAMED_ENUM)
    @Column(nullable = false, columnDefinition = "order_status")
    private OrderStatus status;

    @Column(name = "occurred_at", nullable = false)
    private Instant occurredAt;

    @Column(name = "actor_id")
    private String actorId;

    private String note;

    /**
     * 用途：建立一筆訂單狀態歷程實體，記錄訂單在指定時間發生的狀態變化與備註。
     * 核心重點：集中初始化必要欄位；actorId 未由此工廠方法設定，因此會維持 null。
     */
    public static OrderStatusHistory of(
            String orderId,
            OrderStatus status,
            Instant occurredAt,
            String note) {
        OrderStatusHistory history = new OrderStatusHistory();

        history.orderId = orderId;
        history.status = status;
        history.occurredAt = occurredAt;
        history.note = note;

        return history;
    }
}
