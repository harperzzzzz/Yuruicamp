package com.yuruicamp.backend.booking.application;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.Optional;

import com.yuruicamp.backend.booking.infrastructure.AdminBookingCommandRepository;
import com.yuruicamp.backend.booking.infrastructure.AdminBookingReadRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AdminBookingServiceTest {

	@Mock
	private AdminBookingReadRepository readRepository;

	@Mock
	private AdminBookingCommandRepository commandRepository;

	private AdminBookingService service;

	@BeforeEach
	void setUp() {
		service = new AdminBookingService(readRepository, commandRepository,
				Clock.fixed(Instant.parse("2026-07-21T00:00:00Z"), ZoneOffset.UTC));
	}

	@Test
	void unpaidBookingCannotBeConfirmed() {
		when(commandRepository.lockById("B1")).thenReturn(Optional.of(
				new AdminBookingCommandRepository.BookingState("B1", "pending", "unpaid", LocalDate.of(2026, 7, 20))));

		assertThatThrownBy(() -> service.confirm("B1", "A1", null))
				.isInstanceOf(BusinessException.class);
	}

	@Test
	void paidConfirmedBookingAfterCheckoutCanBeCompleted() {
		when(commandRepository.lockById("B1")).thenReturn(Optional.of(
				new AdminBookingCommandRepository.BookingState("B1", "confirmed", "paid", LocalDate.of(2026, 7, 20))));
		when(readRepository.findDetail("B1")).thenReturn(Optional.of(detail()));

		service.complete("B1", "A1", null);

		verify(commandRepository).fulfillRentalReservations(org.mockito.ArgumentMatchers.eq("B1"),
				org.mockito.ArgumentMatchers.any(Instant.class));
	}

	private static AdminBookingReadRepository.DetailRow detail() {
		return new AdminBookingReadRepository.DetailRow(
				"B1", "C1", "Customer", "active", "C002", "Camp", "北部",
				LocalDate.of(2026, 7, 18), LocalDate.of(2026, 7, 20), 2, 2, 0,
				java.math.BigDecimal.ZERO, java.math.BigDecimal.ZERO, java.math.BigDecimal.ZERO,
				java.math.BigDecimal.ZERO, "ecpay-credit", "paid", Instant.EPOCH,
				"completed", Instant.EPOCH, Instant.EPOCH);
	}
}
