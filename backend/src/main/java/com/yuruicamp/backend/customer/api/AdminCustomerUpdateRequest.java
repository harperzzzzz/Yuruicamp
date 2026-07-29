package com.yuruicamp.backend.customer.api;

import java.time.LocalDate;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.PastOrPresent;
import jakarta.validation.constraints.Size;

@JsonIgnoreProperties(ignoreUnknown = false)
public record AdminCustomerUpdateRequest(
		@Size(min = 1, max = 100) String name,
		@Size(max = 32) String phone,
		@PastOrPresent LocalDate birthday,
		@Min(0) Integer points) {
}
