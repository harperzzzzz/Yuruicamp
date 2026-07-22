package com.yuruicamp.backend.order.domain;

import jakarta.persistence.AttributeConverter;
import jakarta.persistence.Converter;

@Converter
public class PaymentMethodConverter implements AttributeConverter<PaymentMethod, String> {

    @Override
    public String convertToDatabaseColumn(PaymentMethod value) {
        if (value == null) {
            return null;
        }

        String databaseValue = value.name()
                .replace('_', '-');

        return databaseValue;
    }

    @Override
    public PaymentMethod convertToEntityAttribute(String value) {
        if (value == null) {
            return null;
        }

        String enumValue = value.replace('-', '_');

        return PaymentMethod.valueOf(enumValue);
    }
}
