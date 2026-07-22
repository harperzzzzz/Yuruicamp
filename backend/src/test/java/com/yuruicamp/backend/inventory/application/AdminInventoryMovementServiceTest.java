package com.yuruicamp.backend.inventory.application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import com.yuruicamp.backend.inventory.api.AdminInventoryMovementCreateRequest;
import com.yuruicamp.backend.inventory.infrastructure.AdminInventoryMovementRepository;
import org.junit.jupiter.api.Test;

class AdminInventoryMovementServiceTest {

	@Test
	void listRejectsSortOutsideWhitelist() {
		AdminInventoryMovementService service = service();

		BusinessException error = assertThrows(BusinessException.class, () ->
				service.list(0, 20, "", "", "", "", "reason,asc"));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}

	@Test
	void receiptRequiresDestinationOnly() {
		AdminInventoryMovementService service = service();
		AdminInventoryMovementCreateRequest request = new AdminInventoryMovementCreateRequest(
				"store",
				"receipt",
				"SOURCE",
				"DESTINATION",
				"測試進貨",
				null);

		BusinessException error = assertThrows(BusinessException.class, () ->
				service.createDraft("ADMIN", request));

		assertEquals(ErrorCode.VALIDATION_ERROR, error.getErrorCode());
	}

	private AdminInventoryMovementService service() {
		return new AdminInventoryMovementService(mock(AdminInventoryMovementRepository.class));
	}
}
