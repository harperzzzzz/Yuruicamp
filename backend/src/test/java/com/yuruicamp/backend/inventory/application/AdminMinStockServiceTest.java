package com.yuruicamp.backend.inventory.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.inventory.api.AdminMinStockItemRequest;
import com.yuruicamp.backend.inventory.api.AdminMinStockResponse;
import com.yuruicamp.backend.inventory.api.AdminMinStockUpsertRequest;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository.LocationRow;
import com.yuruicamp.backend.inventory.infrastructure.AdminMinStockRepository.MinStockRow;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 單元測試：domain／負數／錯庫位；確認只呼叫 upsert、不碰 on_hand API。
 * Unit tests for min-stock validation and upsert-only behavior.
 */
@ExtendWith(MockitoExtension.class)
class AdminMinStockServiceTest {

	@Mock
	private AdminMinStockRepository repository;

	@InjectMocks
	private AdminMinStockService service;

	@Test
	void upsertStoreWritesThreshold() {
		when(repository.storeVariantExists("V-W107")).thenReturn(true);
		when(repository.findActiveLocation("main"))
				.thenReturn(new LocationRow("main", "store", true));
		when(repository.findStoreOne("V-W107", "main"))
				.thenReturn(new MinStockRow("store", "V-W107", "P-W107", "main", 3, Instant.parse("2026-07-23T00:00:00Z")));

		List<AdminMinStockResponse> result = service.upsert(new AdminMinStockUpsertRequest(
				"store",
				List.of(new AdminMinStockItemRequest("V-W107", "main", 3))));

		assertEquals(1, result.size());
		assertEquals(3, result.get(0).minimumQuantity());
		verify(repository).upsertStore(eq("V-W107"), eq("main"), eq(3), any(Instant.class));
		verify(repository, never()).upsertRental(any(), any(), anyInt(), any());
	}

	@Test
	void rejectNegativeQuantity() {
		BusinessException ex = assertThrows(BusinessException.class, () -> service.upsert(
				new AdminMinStockUpsertRequest(
						"store",
						List.of(new AdminMinStockItemRequest("V-W107", "main", -1)))));
		assertEquals(ErrorCode.VALIDATION_ERROR, ex.getErrorCode());
		verify(repository, never()).upsertStore(any(), any(), anyInt(), any());
	}

	@Test
	void rejectWrongDomainLocation() {
		when(repository.storeVariantExists("V-W107")).thenReturn(true);
		when(repository.findActiveLocation("RENTAL-C001"))
				.thenReturn(new LocationRow("RENTAL-C001", "rental", true));

		BusinessException ex = assertThrows(BusinessException.class, () -> service.upsert(
				new AdminMinStockUpsertRequest(
						"store",
						List.of(new AdminMinStockItemRequest("V-W107", "RENTAL-C001", 2)))));
		assertEquals(ErrorCode.VALIDATION_ERROR, ex.getErrorCode());
	}

	@Test
	void rejectUnknownDomain() {
		BusinessException ex = assertThrows(BusinessException.class, () -> service.list(
				"warehouse", null, null, null));
		assertEquals(ErrorCode.VALIDATION_ERROR, ex.getErrorCode());
	}
}
