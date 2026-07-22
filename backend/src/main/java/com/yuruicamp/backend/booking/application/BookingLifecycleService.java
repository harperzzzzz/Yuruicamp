package com.yuruicamp.backend.booking.application;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

import com.yuruicamp.backend.booking.api.BookingCheckoutSessionResponse;
import com.yuruicamp.backend.booking.infrastructure.BookingLifecycleRepository;
import com.yuruicamp.backend.booking.infrastructure.BookingLifecycleRepository.LockedBookingRow;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

// E-6 在同一交易內取消 Booking、釋放租借保留並新增狀態歷程。
@Service
public class BookingLifecycleService {

	private final BookingLifecycleRepository repository;
	private final BookingMemberService memberService;
	private final Clock clock;

	public BookingLifecycleService(
			BookingLifecycleRepository repository,
			BookingMemberService memberService,
			Clock clock) {
		this.repository = repository;
		this.memberService = memberService;
		this.clock = clock;
	}

	// 會員重複取消已 cancelled 的 Booking 時直接回傳目前結果，保持冪等。
	@Transactional
	public BookingCheckoutSessionResponse cancel(String customerId, String bookingId) {
		if (customerId == null || customerId.isBlank()
				|| bookingId == null || bookingId.isBlank()) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Booking not found");
		}

		LockedBookingRow booking = repository.lockOwnedBooking(customerId, bookingId.trim())
				.orElseThrow(() -> new BusinessException(ErrorCode.NOT_FOUND, "Booking not found"));
		if ("cancelled".equals(booking.status())) {
			return memberService.getCheckoutSession(customerId, booking.id());
		}
		if (!booking.isPendingUnpaid()) {
			throw new BusinessException(
					ErrorCode.CONFLICT,
					"Only pending and unpaid booking checkout can be cancelled");
		}

		Instant now = clock.instant();
		transitionToCancelled(booking.id(), now, "Booking checkout cancelled by customer");

		return memberService.getCheckoutSession(customerId, booking.id());
	}

	// 排程候選取得後逐筆加鎖重查，付款或取消先完成時就跳過該筆。
	@Transactional
	public int expireDueCheckouts(Instant now) {
		Objects.requireNonNull(now, "now must not be null");
		List<String> dueBookingIds = repository.findDueBookingIds(now);
		int expiredCount = 0;

		for (String bookingId : dueBookingIds) {
			LockedBookingRow booking = repository.lockBooking(bookingId)
					.orElse(null);
			if (booking == null || !booking.isPendingUnpaid() || !booking.isDue(now)) {
				continue;
			}

			transitionToCancelled(booking.id(), now, "Booking checkout expired");
			expiredCount++;
		}

		return expiredCount;
	}

	private void transitionToCancelled(String bookingId, Instant occurredAt, String note) {
		repository.cancelBooking(bookingId, occurredAt);
		repository.releaseActiveRentalReservations(bookingId, occurredAt);
		repository.insertCancelledHistory(bookingId, occurredAt, note);
	}
}
