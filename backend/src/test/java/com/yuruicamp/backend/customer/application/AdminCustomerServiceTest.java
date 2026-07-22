package com.yuruicamp.backend.customer.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.domain.CustomerStatus;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerReadRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerRow;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import org.junit.jupiter.api.Test;

class AdminCustomerServiceTest {

	@Test
	void listRejectsSortOutsideWhitelist() {
		AdminCustomerService service = new AdminCustomerService(
				mock(CustomerRepository.class),
				mock(AdminCustomerReadRepository.class));

		BusinessException error = assertThrows(BusinessException.class, () ->
				service.list(0, 20, "", "", "", List.of(), "email,asc"));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}

	@Test
	void listUsesExplorerAndZeroSpentFromReadModel() {
		AdminCustomerReadRepository readRepository = mock(AdminCustomerReadRepository.class);
		when(readRepository.findIds(0, 20, "", "", "", List.of(), "registeredAt", "DESC"))
				.thenReturn(new AdminCustomerReadRepository.IdPage(List.of("C1"), 1));
		when(readRepository.findRows(List.of("C1"))).thenReturn(List.of(new AdminCustomerRow(
				"C1", "會員", null, "c1@example.com", CustomerStatus.active, Instant.now(),
				"explorer", "探險家", BigDecimal.ZERO, 0)));
		when(readRepository.findTags(List.of("C1"))).thenReturn(Map.of());
		AdminCustomerService service = new AdminCustomerService(mock(CustomerRepository.class), readRepository);

		var result = service.list(0, 20, "", "", "", List.of(), "registeredAt,desc");

		assertEquals("0.00", result.data().getFirst().totalSpent());
		assertEquals("explorer", result.data().getFirst().tier());
		assertEquals(1, result.meta().totalElements());
	}

	@Test
	void deletedCustomerCannotBeReactivated() {
		CustomerRepository customerRepository = mock(CustomerRepository.class);
		Customer customer = new Customer();
		customer.setId("C-DELETED");
		customer.setStatus(CustomerStatus.deleted);
		when(customerRepository.findByIdForUpdate("C-DELETED")).thenReturn(Optional.of(customer));
		AdminCustomerService service = new AdminCustomerService(
				customerRepository,
				mock(AdminCustomerReadRepository.class));

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> service.reactivate("C-DELETED"));

		assertEquals(ErrorCode.CONFLICT, error.getErrorCode());
		verify(customerRepository).findByIdForUpdate("C-DELETED");
	}
}
