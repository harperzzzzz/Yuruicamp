package com.yuruicamp.backend.customer.application;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.customer.api.MemberShippingAddressRequest;
import com.yuruicamp.backend.customer.api.MemberShippingAddressResponse;
import com.yuruicamp.backend.customer.domain.Customer;
import com.yuruicamp.backend.customer.infrastructure.CustomerRepository;
import com.yuruicamp.backend.customer.infrastructure.MemberShippingAddressRepository;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MemberShippingAddressService {

	private final CustomerRepository customerRepository;
	private final MemberShippingAddressRepository addressRepository;

	public MemberShippingAddressService(
			CustomerRepository customerRepository,
			MemberShippingAddressRepository addressRepository) {
		this.customerRepository = customerRepository;
		this.addressRepository = addressRepository;
	}

	@Transactional(readOnly = true)
	public MemberShippingAddressResponse getDefault(String customerId) {
		return addressRepository.findDefault(customerId).orElse(null);
	}

	@Transactional
	public MemberShippingAddressResponse saveDefault(
			String customerId,
			MemberShippingAddressRequest request) {
		Customer customer = customerRepository.findByIdForUpdate(customerId)
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Customer not found"));

		// 地址 Email 是會員 Email 的投影，不允許以地址表單變更登入信箱。
		if (!customer.getEmail().equalsIgnoreCase(request.email().trim())) {
			throw new BusinessException(
					ErrorCode.VALIDATION_ERROR,
					"Shipping address email must match the authenticated customer email");
		}

		addressRepository.findDefault(customerId).ifPresentOrElse(
				address -> addressRepository.updateDefault(address.id(), request),
				() -> addressRepository.insertDefault(customerId, request));

		return addressRepository.findDefault(customerId)
				.orElseThrow(() -> new BusinessException(
						ErrorCode.INTERNAL_ERROR,
						"Shipping address was not persisted"));
	}
}
