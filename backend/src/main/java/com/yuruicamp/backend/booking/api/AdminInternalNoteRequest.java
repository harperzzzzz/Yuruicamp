package com.yuruicamp.backend.booking.api;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import jakarta.validation.constraints.Size;

/**
 * 後台預約內部備註覆寫請求。
 * Admin booking internal note overwrite request.
 *
 * 空白字串由 Service 正規化為 null（清除備註）。
 * Blank strings are normalized to null by the service (clears the note).
 */
@JsonIgnoreProperties(ignoreUnknown = false)
public record AdminInternalNoteRequest(
		@Size(max = 2000) String internalNote) {
}
