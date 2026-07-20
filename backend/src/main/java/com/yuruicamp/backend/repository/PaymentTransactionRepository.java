package com.yuruicamp.backend.repository;

import com.yuruicamp.backend.entity.PaymentTransaction;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface PaymentTransactionRepository extends JpaRepository<PaymentTransaction, Long> {

    boolean existsByMerchantTradeNo(String merchantTradeNo);

    Optional<PaymentTransaction> findByMerchantTradeNo(String merchantTradeNo);
}
