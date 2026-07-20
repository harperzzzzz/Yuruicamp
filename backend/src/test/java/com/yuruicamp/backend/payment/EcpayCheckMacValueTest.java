package com.yuruicamp.backend.payment;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.LinkedHashMap;
import java.util.Map;
import org.junit.jupiter.api.Test;

class EcpayCheckMacValueTest {

    private final EcpayCheckMacValue checkMacValue = new EcpayCheckMacValue();

    @Test
    void generatesOfficialAioSha256Vector() {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("MerchantID", "3002607");
        fields.put("MerchantTradeNo", "Test1234567890");
        fields.put("MerchantTradeDate", "2025/01/01 12:00:00");
        fields.put("PaymentType", "aio");
        fields.put("TotalAmount", "100");
        fields.put("TradeDesc", "測試");
        fields.put("ItemName", "測試商品");
        fields.put("ReturnURL", "https://example.com/notify");
        fields.put("ChoosePayment", "ALL");
        fields.put("EncryptType", "1");

        String result = checkMacValue.generate(
                fields, "pwFHCqoQZGmho4w6", "EkRm7iFT261dpevs");

        assertThat(result).isEqualTo("291CBA324D31FB5A4BBBFDF2CFE5D32598524753AFD4959C3BF590C5B2F57FB2");
    }

    @Test
    void verifiesWithTimingSafeComparison() {
        Map<String, String> fields = new LinkedHashMap<>();
        fields.put("MerchantID", "3002607");
        fields.put("MerchantTradeNo", "YRC260721120000000");
        fields.put("RtnCode", "1");
        fields.put("TotalAmount", "100");
        fields.put("TradeNo", "2507211234567890");
        fields.put("CheckMacValue", checkMacValue.generate(
                fields, "pwFHCqoQZGmho4w6", "EkRm7iFT261dpevs"));

        assertThat(checkMacValue.verify(fields, "pwFHCqoQZGmho4w6", "EkRm7iFT261dpevs")).isTrue();
    }
}
