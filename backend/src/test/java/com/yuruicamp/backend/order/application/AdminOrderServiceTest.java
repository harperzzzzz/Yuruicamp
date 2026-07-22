package com.yuruicamp.backend.order.application;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.order.infrastructure.AdminOrderCommandRepository;
import com.yuruicamp.backend.order.infrastructure.AdminOrderReadRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminOrderServiceTest {

	@Mock
	private AdminOrderReadRepository readRepository;

	@Mock
	private AdminOrderCommandRepository commandRepository;

	private AdminOrderService service;

	@BeforeEach
	void setUp() {
		service = new AdminOrderService(readRepository, commandRepository);
	}

	@Test
	void paidOnlineOrderCanBeShipped() {
		when(commandRepository.lockById("O1")).thenReturn(Optional.of(
				new AdminOrderCommandRepository.OrderState("O1", "unshipped", "ecpay-credit", "paid", "none")));
		when(readRepository.findDetail("O1")).thenReturn(Optional.of(detail("shipped")));

		service.ship("O1", "A1", null);

		verify(commandRepository).updateStatus(org.mockito.ArgumentMatchers.eq("O1"),
				org.mockito.ArgumentMatchers.eq("shipped"), org.mockito.ArgumentMatchers.any(Instant.class));
		verify(commandRepository).addHistory(org.mockito.ArgumentMatchers.eq("O1"),
				org.mockito.ArgumentMatchers.eq("shipped"), org.mockito.ArgumentMatchers.any(Instant.class),
				org.mockito.ArgumentMatchers.eq("A1"), org.mockito.ArgumentMatchers.anyString());
	}

	@Test
	void unpaidOnlineOrderCannotBeShipped() {
		when(commandRepository.lockById("O1")).thenReturn(Optional.of(
				new AdminOrderCommandRepository.OrderState("O1", "unshipped", "ecpay-credit", "unpaid", "none")));

		assertThatThrownBy(() -> service.ship("O1", "A1", null))
				.isInstanceOf(BusinessException.class);
	}

	private static AdminOrderReadRepository.DetailRow detail(String status) {
		return new AdminOrderReadRepository.DetailRow(
				"O1", "C1", "Customer", "active", "Buyer", "buyer@example.test",
				"Recipient", "0900", "Address", java.math.BigDecimal.ZERO,
				java.math.BigDecimal.ZERO, java.math.BigDecimal.ZERO, java.math.BigDecimal.ZERO,
				"ecpay-credit", "paid", "none", status, Instant.EPOCH, Instant.EPOCH, Instant.EPOCH);
	}
}
