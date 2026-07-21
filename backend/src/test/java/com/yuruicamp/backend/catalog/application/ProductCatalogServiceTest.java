package com.yuruicamp.backend.catalog.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.yuruicamp.backend.catalog.infrastructure.EquipmentImageRepository;
import com.yuruicamp.backend.catalog.infrastructure.ProductRepository;
import com.yuruicamp.backend.catalog.infrastructure.VariantAvailabilityRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;

class ProductCatalogServiceTest {

	@Test
	void listProductsReturnsContractMetaForAnEmptyPage() {
		ProductRepository productRepository = mock(ProductRepository.class);
		when(productRepository.findActiveIdsForCatalog(any(), any(), any(), any(), any(Pageable.class)))
				.thenReturn(Page.empty(org.springframework.data.domain.PageRequest.of(2, 10)));
		ProductCatalogService service = new ProductCatalogService(
				productRepository,
				mock(EquipmentImageRepository.class),
				mock(ProductCatalogAssembler.class),
				mock(VariantAvailabilityRepository.class));

		ProductCatalogService.PagedProducts result = service.listProducts(
				2, 10, "name,desc", null, null, null, null);

		assertEquals(2, result.meta().page());
		assertEquals(10, result.meta().size());
		assertEquals(0, result.meta().totalElements());
		assertEquals(0, result.meta().totalPages());
		assertEquals(0, result.data().size());
		verify(productRepository).findActiveIdsForCatalog(
				eq(""),
				eq(""),
				eq(java.math.BigDecimal.ZERO),
				eq(new java.math.BigDecimal("9999999999.99")),
				any(Pageable.class));
	}

	@Test
	void listProductsRejectsSortOutsideTheContractWhitelist() {
		ProductCatalogService service = new ProductCatalogService(
				mock(ProductRepository.class),
				mock(EquipmentImageRepository.class),
				mock(ProductCatalogAssembler.class),
				mock(VariantAvailabilityRepository.class));

		BusinessException error = assertThrows(
				BusinessException.class,
				() -> service.listProducts(0, 20, "price,asc", null, null, null, null));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}
}
