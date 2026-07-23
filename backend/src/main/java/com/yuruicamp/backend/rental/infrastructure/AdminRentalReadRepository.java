package com.yuruicamp.backend.rental.infrastructure;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.yuruicamp.backend.rental.api.AdminRentalResponse;
import com.yuruicamp.backend.rental.api.AdminRentalVariantResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台租借 SKU 讀模型：先分頁出 {@code rental_skus.id}，再批次組回規格清單。
 * Admin rental SKU read model：paginate ids first, then batch-assemble variants.
 *
 * <p>寫法完全對齊 {@code AdminProductReadRepository}，方便新手比對兩者差異
 * （主要差異：沒有圖片、沒有唯讀庫存，因為租借的庫存／定價不在這個 API 範圍）。</p>
 */
@Repository
public class AdminRentalReadRepository {

	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"id", "sku.id",
			"name", "item.name",
			"createdAt", "sku.created_at",
			"updatedAt", "sku.updated_at");

	private final NamedParameterJdbcTemplate jdbc;

	public AdminRentalReadRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public static String resolveSortColumn(String sortField) {
		return SORT_COLUMNS.get(sortField);
	}

	public IdPage findIds(
			int page,
			int size,
			String query,
			String status,
			Long categoryId,
			String brandId,
			String sortField,
			String sortDirection) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("query", "%" + query.toLowerCase(Locale.ROOT) + "%")
				.addValue("limit", size)
				.addValue("offset", page * size);
		String where = buildWhere(parameters, status, categoryId, brandId);
		String from = " FROM rental_skus sku JOIN equipment_items item ON item.id = sku.item_id ";
		long totalElements = jdbc.queryForObject(
				"SELECT count(*) " + from + where,
				parameters,
				Long.class);
		String orderBy = SORT_COLUMNS.get(sortField) + " " + sortDirection + ", sku.id ASC";
		List<String> ids = jdbc.queryForList(
				"SELECT sku.id " + from + where + " ORDER BY " + orderBy
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				String.class);

		return new IdPage(ids, totalElements);
	}

	public List<AdminRentalResponse> findRentals(List<String> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		MapSqlParameterSource parameters = new MapSqlParameterSource("ids", ids);
		List<RentalHeader> headers = jdbc.query("""
				SELECT sku.id, sku.item_id, sku.status,
				       item.name, item.description, item.category_id,
				       category.name AS category_name,
				       item.brand_id, brand.name AS brand_name,
				       sku.created_at, sku.updated_at
				FROM rental_skus sku
				JOIN equipment_items item ON item.id = sku.item_id
				JOIN product_categories category ON category.id = item.category_id
				LEFT JOIN brands brand ON brand.id = item.brand_id
				WHERE sku.id IN (:ids)
				""", parameters, (row, rowNumber) -> new RentalHeader(
				row.getString("id"),
				row.getString("item_id"),
				row.getString("status"),
				row.getString("name"),
				row.getString("description"),
				row.getLong("category_id"),
				row.getString("category_name"),
				row.getString("brand_id"),
				row.getString("brand_name"),
				row.getObject("created_at", OffsetDateTime.class),
				row.getObject("updated_at", OffsetDateTime.class)));

		Map<String, List<AdminRentalVariantResponse>> variantsById = findVariants(parameters);
		Map<String, RentalHeader> headersById = new HashMap<>();
		headers.forEach(header -> headersById.put(header.id(), header));

		List<AdminRentalResponse> result = new ArrayList<>();
		for (String id : ids) {
			RentalHeader header = headersById.get(id);
			if (header == null) {
				continue;
			}
			result.add(toResponse(header, variantsById.getOrDefault(id, List.of())));
		}

		return result;
	}

	private Map<String, List<AdminRentalVariantResponse>> findVariants(MapSqlParameterSource parameters) {
		Map<String, List<AdminRentalVariantResponse>> result = new LinkedHashMap<>();
		jdbc.query("""
				SELECT rental_sku_id, id, sku, color, size, specification, status, created_at, updated_at
				FROM rental_sku_variants
				WHERE rental_sku_id IN (:ids)
				ORDER BY rental_sku_id, id
				""", parameters, row -> {
			AdminRentalVariantResponse variant = new AdminRentalVariantResponse(
					row.getString("id"),
					row.getString("sku"),
					row.getString("color"),
					row.getString("size"),
					row.getString("specification"),
					row.getString("status"),
					row.getObject("created_at", OffsetDateTime.class).toInstant(),
					row.getObject("updated_at", OffsetDateTime.class).toInstant());
			result.computeIfAbsent(row.getString("rental_sku_id"), ignored -> new ArrayList<>())
					.add(variant);
		});

		return result;
	}

	private String buildWhere(
			MapSqlParameterSource parameters,
			String status,
			Long categoryId,
			String brandId) {
		StringBuilder where = new StringBuilder("""
				 WHERE (lower(sku.id) LIKE :query
				    OR lower(item.name) LIKE :query
				    OR EXISTS (
				        SELECT 1 FROM rental_sku_variants variant
				        WHERE variant.rental_sku_id = sku.id AND lower(variant.sku) LIKE :query))
				""");
		if (!status.isBlank()) {
			where.append(" AND sku.status = :status");
			parameters.addValue("status", status);
		}
		if (categoryId != null) {
			where.append(" AND item.category_id = :categoryId");
			parameters.addValue("categoryId", categoryId);
		}
		if (!brandId.isBlank()) {
			where.append(" AND item.brand_id = :brandId");
			parameters.addValue("brandId", brandId);
		}

		return where.toString();
	}

	private AdminRentalResponse toResponse(RentalHeader header, List<AdminRentalVariantResponse> variants) {
		return new AdminRentalResponse(
				header.id(), header.itemId(), header.status(), header.name(),
				header.categoryId(), header.category(), header.brandId(), header.brand(),
				header.description(), variants,
				header.createdAt().toInstant(), header.updatedAt().toInstant());
	}

	public record IdPage(List<String> ids, long totalElements) {
	}

	private record RentalHeader(
			String id,
			String itemId,
			String status,
			String name,
			String description,
			Long categoryId,
			String category,
			String brandId,
			String brand,
			OffsetDateTime createdAt,
			OffsetDateTime updatedAt) {
	}
}
