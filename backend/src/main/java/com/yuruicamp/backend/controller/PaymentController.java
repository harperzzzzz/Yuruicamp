package com.yuruicamp.backend.controller;

import com.yuruicamp.backend.dto.CreatePaymentRequest;
import com.yuruicamp.backend.dto.CreatePaymentResponse;
import com.yuruicamp.backend.dto.PaymentStatusResponse;
import com.yuruicamp.backend.service.PaymentService;
import jakarta.validation.Valid;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/payments")
public class PaymentController {

    private final PaymentService paymentService;

    public PaymentController(PaymentService paymentService) {
        this.paymentService = paymentService;
    }

    @PostMapping
    public CreatePaymentResponse createPayment(@Valid @RequestBody CreatePaymentRequest request) {
        return paymentService.createPayment(request);
    }

    @PostMapping(
            value = "/ecpay/return",
            consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE,
            produces = MediaType.TEXT_PLAIN_VALUE)
    public ResponseEntity<String> handleEcpayReturn(@RequestParam Map<String, String> fields) {
        return ResponseEntity.ok()
                .contentType(MediaType.TEXT_PLAIN)
                .body(paymentService.handleEcpayReturn(fields));
    }

    @PostMapping(
            value = "/ecpay/order-result",
            consumes = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    public ResponseEntity<Void> handleEcpayOrderResult(@RequestParam Map<String, String> fields) {
        return ResponseEntity.status(HttpStatus.SEE_OTHER)
                .location(paymentService.buildOrderResultRedirect(fields))
                .build();
    }

    @GetMapping("/{merchantTradeNo}/status")
    public PaymentStatusResponse getPaymentStatus(@PathVariable String merchantTradeNo) {
        return paymentService.getPaymentStatus(merchantTradeNo);
    }
}
