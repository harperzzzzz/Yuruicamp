package com.yuruicamp.backend.common.api;

/** Pagination metadata shared by list APIs. Page numbering is zero-based. */
public record PageMeta(int page, int size, long totalElements, int totalPages) {
}
