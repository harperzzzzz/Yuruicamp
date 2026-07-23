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
import com.yuruicamp.backend.customer.api.AdminCustomerPreferencesReplaceRequest;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.domain.CustomerStatus;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerPreferenceRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerReadRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerRow;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerShippingAddressRepository;
import com.yuruicamp.backend.customer.infrastructure.AdminCustomerTagRepository;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import org.junit.jupiter.api.Test;

class AdminCustomerServiceTest {

	private static AdminCustomerService service(
			CustomerRepository customers,
			AdminCustomerReadRepository read,
			AdminCustomerTagRepository tags,
			AdminCustomerShippingAddressRepository shipping,
			AdminCustomerPreferenceRepository preferences) {
		return new AdminCustomerService(customers, read, tags, shipping, preferences);
	}

	@Test
	void listRejectsSortOutsideWhitelist() {
		AdminCustomerService svc = service(
				mock(CustomerRepository.class),
				mock(AdminCustomerReadRepository.class),
				mock(AdminCustomerTagRepository.class),
				mock(AdminCustomerShippingAddressRepository.class),
				mock(AdminCustomerPreferenceRepository.class));

		BusinessException error = assertThrows(BusinessException.class, () ->
				svc.list(0, 20, "", "", "", List.of(), "email,asc"));

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
		AdminCustomerService svc = service(
				mock(CustomerRepository.class),
				readRepository,
				mock(AdminCustomerTagRepository.class),
				mock(AdminCustomerShippingAddressRepository.class),
				mock(AdminCustomerPreferenceRepository.class));

		var result = svc.list(0, 20, "", "", "", List.of(), "registeredAt,desc");

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
		AdminCustomerService svc = service(
				customerRepository,
				mock(AdminCustomerReadRepository.class),
				mock(AdminCustomerTagRepository.class),
				mock(AdminCustomerShippingAddressRepository.class),
				mock(AdminCustomerPreferenceRepository.class));

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> svc.reactivate("C-DELETED"));

		assertEquals(ErrorCode.CONFLICT, error.getErrorCode());
		verify(customerRepository).findByIdForUpdate("C-DELETED");
	}

	@Test
	void replacePreferencesRejectsInactiveOrUnknownOptionIds() {
		CustomerRepository customerRepository = mock(CustomerRepository.class);
		AdminCustomerPreferenceRepository preferenceRepository = mock(AdminCustomerPreferenceRepository.class);
		Customer customer = new Customer();
		customer.setId("C1");
		customer.setStatus(CustomerStatus.active);
		when(customerRepository.findByIdForUpdate("C1")).thenReturn(Optional.of(customer));
		when(preferenceRepository.findActiveIds(List.of(2L, 999L))).thenReturn(List.of(2L));

		AdminCustomerService svc = service(
				customerRepository,
				mock(AdminCustomerReadRepository.class),
				mock(AdminCustomerTagRepository.class),
				mock(AdminCustomerShippingAddressRepository.class),
				preferenceRepository);

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> svc.replacePreferences("C1", new AdminCustomerPreferencesReplaceRequest(List.of(2L, 999L))));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}

	@Test
	void replacePreferencesRejectsDeletedCustomer() {
		CustomerRepository customerRepository = mock(CustomerRepository.class);
		Customer customer = new Customer();
		customer.setId("C-DELETED");
		customer.setStatus(CustomerStatus.deleted);
		when(customerRepository.findByIdForUpdate("C-DELETED")).thenReturn(Optional.of(customer));

		AdminCustomerService svc = service(
				customerRepository,
				mock(AdminCustomerReadRepository.class),
				mock(AdminCustomerTagRepository.class),
				mock(AdminCustomerShippingAddressRepository.class),
				mock(AdminCustomerPreferenceRepository.class));

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> svc.replacePreferences(
						"C-DELETED",
						new AdminCustomerPreferencesReplaceRequest(List.of(1L))));

		assertEquals(ErrorCode.CONFLICT, error.getErrorCode());
	}
}
