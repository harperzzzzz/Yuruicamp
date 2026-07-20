package com.yuruicamp.backend.order.domain;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class PaymentMethodConverter implements AttributeConverter<PaymentMethod, String> {
	@Override public String convertToDatabaseColumn(PaymentMethod value) {
		return value == null ? null : value.name().replace('_', '-');
	}
	@Override public PaymentMethod convertToEntityAttribute(String value) {
		return value == null ? null : PaymentMethod.valueOf(value.replace('-', '_'));
	}
}
