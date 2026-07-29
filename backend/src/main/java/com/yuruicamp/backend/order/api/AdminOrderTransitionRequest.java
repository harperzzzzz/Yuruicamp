package com.yuruicamp.backend.order.api;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Size;

// 後台訂單履約命令只接受選填備註，操作者由登入身分取得。
@JsonIgnoreProperties(ignoreUnknown = false)
public record AdminOrderTransitionRequest(@Size(max = 500) String note) {
}
