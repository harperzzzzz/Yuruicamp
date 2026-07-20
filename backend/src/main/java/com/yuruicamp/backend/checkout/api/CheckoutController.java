package com.yuruicamp.backend.checkout.api;

import com.yuruicamp.backend.checkout.application.CheckoutService;
import com.yuruicamp.backend.common.api.ApiResponse;
import com.yuruicamp.backend.common.security.CustomerPrincipal;
import jakarta.validation.Valid;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import io.swagger.v3.oas.annotations.tags.Tag;

@RestController @RequestMapping("/api/checkout/sessions") @Tag(name="Checkout",description="Draft order and 15-minute stock reservation")
public class CheckoutController {
	private final CheckoutService service; public CheckoutController(CheckoutService service){this.service=service;}
	@PostMapping public ApiResponse<CheckoutSessionResponse> create(@AuthenticationPrincipal CustomerPrincipal principal,@Valid @RequestBody CheckoutCreateRequest request){return ApiResponse.ok(service.create(principal.customerId(),request));}
	@PostMapping("/{orderId}/cancel") public ApiResponse<CheckoutSessionResponse> cancel(@AuthenticationPrincipal CustomerPrincipal principal,@PathVariable String orderId){return ApiResponse.ok(service.cancel(principal.customerId(),orderId));}
}
