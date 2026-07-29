package com.yuruicamp.backend.integration.line.api;

import jakarta.validation.constraints.NotBlank;

// 會員產生綁定碼的請求：只需帶入自己要詢問的來源訂單編號。
public record LineBindingCodeRequest(@NotBlank String orderId) {
}
