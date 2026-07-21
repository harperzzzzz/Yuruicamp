package com.yuruicamp.backend.booking.api;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Size;

// 後台預約履約命令只接受選填備註。
@JsonIgnoreProperties(ignoreUnknown = false)
public record AdminBookingTransitionRequest(@Size(max = 500) String note) {
}
