package com.yuruicamp.backend.customer.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.Optional;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.api.MemberShippingAddressRequest;
import com.yuruicamp.backend.customer.api.MemberShippingAddressResponse;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import com.yuruicamp.backend.customer.infrastructure.MemberShippingAddressRepository;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MemberShippingAddressServiceTest {

	@Mock
	private CustomerRepository customerRepository;

	@Mock
	private MemberShippingAddressRepository addressRepository;

	private MemberShippingAddressService service;

	@BeforeEach
	void setUp() {
		service = new MemberShippingAddressService(customerRepository, addressRepository);
	}

	@Test
	void insertsFirstDefaultAddressForAuthenticatedCustomer() {
		Customer customer = customer("member@example.test");
		MemberShippingAddressRequest request = request("member@example.test");
		MemberShippingAddressResponse saved = response("member@example.test");
		when(customerRepository.findByIdForUpdate("C001")).thenReturn(Optional.of(customer));
		when(addressRepository.findDefault("C001"))
				.thenReturn(Optional.empty())
				.thenReturn(Optional.of(saved));

		MemberShippingAddressResponse result = service.saveDefault("C001", request);

		verify(addressRepository).insertDefault("C001", request);
		assertThat(result).isEqualTo(saved);
	}

	@Test
	void rejectsAddressEmailThatDoesNotMatchCustomer() {
		when(customerRepository.findByIdForUpdate("C001"))
				.thenReturn(Optional.of(customer("member@example.test")));

		assertThatThrownBy(() -> service.saveDefault("C001", request("other@example.test")))
				.isInstanceOfSatisfying(BusinessException.class, error ->
						assertThat(error.getErrorCode()).isEqualTo(ErrorCode.VALIDATION_ERROR));
	}

	@Test
	void updatesExistingDefaultAddressInsteadOfInsertingAnother() {
		Customer customer = customer("member@example.test");
		MemberShippingAddressRequest request = request("member@example.test");
		MemberShippingAddressResponse existing = response("member@example.test");
		when(customerRepository.findByIdForUpdate("C001")).thenReturn(Optional.of(customer));
		when(addressRepository.findDefault("C001")).thenReturn(Optional.of(existing));

		MemberShippingAddressResponse result = service.saveDefault("C001", request);

		verify(addressRepository).updateDefault(existing.id(), request);
		assertThat(result).isEqualTo(existing);
	}

	private Customer customer(String email) {
		Customer customer = new Customer();
		customer.setId("C001");
		customer.setEmail(email);
		return customer;
	}

	private MemberShippingAddressRequest request(String email) {
		return new MemberShippingAddressRequest(
				"王小明", "701", "臺南市", "東區", "長榮路二段200號", "0912345678", email);
	}

	private MemberShippingAddressResponse response(String email) {
		return new MemberShippingAddressResponse(
				1L, "王小明", "701", "臺南市", "東區", "長榮路二段200號", "0912345678", email);
	}
}
