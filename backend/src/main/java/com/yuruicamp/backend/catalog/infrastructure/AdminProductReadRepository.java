package com.yuruicamp.backend.catalog.infrastructure;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.catalog.api.AdminProductImageResponse;
import com.yuruicamp.backend.catalog.api.AdminProductLookupResponse;
import com.yuruicamp.backend.catalog.api.AdminProductResponse;
import com.yuruicamp.backend.catalog.api.AdminProductStockLocationResponse;
import com.yuruicamp.backend.catalog.api.AdminProductVariantResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * 後台商品讀模型，先分頁商品 ID，再批次載入規格、圖片與唯讀庫存。
 */
@Repository
public class AdminProductReadRepository {

	private static final Map<String, String> SORT_COLUMNS = Map.of(
			"id", "product.id",
			"name", "item.name",
			"createdAt", "product.created_at",
			"updatedAt", "product.updated_at");

	private final NamedParameterJdbcTemplate jdbc;

	public AdminProductReadRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
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
				.addValue("query", "%" + query.toLowerCase(java.util.Locale.ROOT) + "%")
				.addValue("limit", size)
				.addValue("offset", page * size);
		String where = buildWhere(parameters, status, categoryId, brandId);
		String from = " FROM products product JOIN equipment_items item ON item.id = product.item_id ";
		long totalElements = jdbc.queryForObject(
				"SELECT count(*) " + from + where,
				parameters,
				Long.class);
		String orderBy = SORT_COLUMNS.get(sortField) + " " + sortDirection + ", product.id ASC";
		List<String> ids = jdbc.queryForList(
				"SELECT product.id " + from + where + " ORDER BY " + orderBy
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				String.class);

		return new IdPage(ids, totalElements);
	}

	public List<AdminProductResponse> findProducts(List<String> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		MapSqlParameterSource parameters = new MapSqlParameterSource("ids", ids);
		List<ProductHeader> headers = jdbc.query("""
				SELECT product.id, product.item_id, product.status,
				       item.name, item.description, item.category_id,
				       category.name AS category_name,
				       item.brand_id, brand.name AS brand_name,
				       product.created_at, product.updated_at
				FROM products product
				JOIN equipment_items item ON item.id = product.item_id
				JOIN product_categories category ON category.id = item.category_id
				LEFT JOIN brands brand ON brand.id = item.brand_id
				WHERE product.id IN (:ids)
				""", parameters, this::mapHeader);
		Map<String, List<AdminProductImageResponse>> imagesByItem = findImages(parameters);
		Map<String, List<VariantRow>> variantsByProduct = findVariants(parameters);
		Map<String, List<AdminProductStockLocationResponse>> stocksByVariant = findStocks(parameters);
		Map<String, ProductHeader> headersById = new HashMap<>();
		headers.forEach(header -> headersById.put(header.id(), header));
		List<AdminProductResponse> result = new ArrayList<>();
		for (String id : ids) {
			ProductHeader header = headersById.get(id);
			if (header == null) {
				continue;
			}
			List<AdminProductImageResponse> images = imagesByItem.getOrDefault(header.itemId(), List.of());
			List<AdminProductVariantResponse> variants = toVariants(
					variantsByProduct.getOrDefault(id, List.of()),
					stocksByVariant);

			result.add(toResponse(header, images, variants));
		}

		return result;
	}

	public AdminProductLookupResponse findLookups() {
		List<AdminProductLookupResponse.CategoryOption> categories = jdbc.query("""
				SELECT id, name
				FROM product_categories
				ORDER BY sort_order, id
				""", (row, rowNumber) -> new AdminProductLookupResponse.CategoryOption(
				row.getLong("id"), row.getString("name")));
		List<AdminProductLookupResponse.BrandOption> brands = jdbc.query("""
				SELECT id, name
				FROM brands
				ORDER BY sort_order, id
				""", (row, rowNumber) -> new AdminProductLookupResponse.BrandOption(
				row.getString("id"), row.getString("name")));

		return new AdminProductLookupResponse(categories, brands);
	}

	private String buildWhere(
			MapSqlParameterSource parameters,
			String status,
			Long categoryId,
			String brandId) {
		StringBuilder where = new StringBuilder("""
				 WHERE (lower(product.id) LIKE :query
				    OR lower(item.name) LIKE :query
				    OR EXISTS (
				        SELECT 1 FROM product_variants variant
				        WHERE variant.product_id = product.id AND lower(variant.sku) LIKE :query))
				""");
		if (!status.isBlank()) {
			where.append(" AND product.status = :status");
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

	private Map<String, List<AdminProductImageResponse>> findImages(MapSqlParameterSource parameters) {
		Map<String, List<AdminProductImageResponse>> result = new HashMap<>();
		jdbc.query("""
				SELECT image.item_id, image.sort_order, image.url, image.alt_text
				FROM equipment_images image
				JOIN products product ON product.item_id = image.item_id
				WHERE product.id IN (:ids)
				ORDER BY image.item_id, image.sort_order
				""", parameters, row -> {
			result.computeIfAbsent(row.getString("item_id"), ignored -> new ArrayList<>())
					.add(new AdminProductImageResponse(
							row.getInt("sort_order"),
							row.getString("url"),
							row.getString("alt_text")));
		});

		return result;
	}

	private Map<String, List<VariantRow>> findVariants(MapSqlParameterSource parameters) {
		Map<String, List<VariantRow>> result = new LinkedHashMap<>();
		jdbc.query("""
				SELECT variant.product_id, variant.id, variant.sku, variant.color,
				       variant.size, variant.specification, variant.price, variant.status
				FROM product_variants variant
				WHERE variant.product_id IN (:ids)
				ORDER BY variant.product_id, variant.id
				""", parameters, row -> {
			VariantRow variant = new VariantRow(
					row.getString("id"),
					row.getString("sku"),
					row.getString("color"),
					row.getString("size"),
					row.getString("specification"),
					row.getObject("price", BigDecimal.class),
					row.getString("status"));
			result.computeIfAbsent(row.getString("product_id"), ignored -> new ArrayList<>())
					.add(variant);
		});

		return result;
	}

	private Map<String, List<AdminProductStockLocationResponse>> findStocks(
			MapSqlParameterSource parameters) {
		Map<String, List<AdminProductStockLocationResponse>> result = new HashMap<>();
		jdbc.query("""
				WITH stock_keys AS (
				    SELECT stock.variant_id, stock.location_id
				    FROM inventory_stocks stock
				    UNION
				    SELECT reservation.variant_id, reservation.location_id
				    FROM product_stock_reservations reservation
				    WHERE reservation.status = 'active'
				), reservations AS (
				    SELECT variant_id, location_id, sum(quantity) AS quantity
				    FROM product_stock_reservations
				    WHERE status = 'active'
				    GROUP BY variant_id, location_id
				)
				SELECT variant.id AS variant_id,
				       location.id AS location_id, location.code AS location_code,
				       location.type AS location_type, location.branch_id, location.name,
				       COALESCE(stock.on_hand_quantity, 0) AS on_hand_quantity,
				       COALESCE(reservation.quantity, 0) AS reserved_quantity
				FROM product_variants variant
				JOIN stock_keys key ON key.variant_id = variant.id
				JOIN inventory_locations location ON location.id = key.location_id
				LEFT JOIN inventory_stocks stock
				       ON stock.variant_id = key.variant_id AND stock.location_id = key.location_id
				LEFT JOIN reservations reservation
				       ON reservation.variant_id = key.variant_id AND reservation.location_id = key.location_id
				WHERE variant.product_id IN (:ids) AND location.inventory_domain = 'store'
				ORDER BY variant.id, location.type, location.id
				""", parameters, row -> {
			int onHand = row.getInt("on_hand_quantity");
			int reserved = row.getInt("reserved_quantity");
			AdminProductStockLocationResponse stock = new AdminProductStockLocationResponse(
					row.getString("location_id"),
					row.getString("location_code"),
					row.getString("location_type"),
					row.getString("branch_id"),
					row.getString("name"),
					onHand,
					reserved,
					Math.max(onHand - reserved, 0));
			result.computeIfAbsent(row.getString("variant_id"), ignored -> new ArrayList<>())
					.add(stock);
		});

		return result;
	}

	private List<AdminProductVariantResponse> toVariants(
			List<VariantRow> rows,
			Map<String, List<AdminProductStockLocationResponse>> stocksByVariant) {
		List<AdminProductVariantResponse> result = new ArrayList<>();
		for (VariantRow row : rows) {
			List<AdminProductStockLocationResponse> locations = stocksByVariant
					.getOrDefault(row.id(), List.of());
			int onHand = locations.stream()
					.mapToInt(AdminProductStockLocationResponse::onHandQuantity)
					.sum();
			int reserved = locations.stream()
					.mapToInt(AdminProductStockLocationResponse::reservedQuantity)
					.sum();
			result.add(new AdminProductVariantResponse(
					row.id(), row.sku(), row.color(), row.size(), row.specification(),
					money(row.price()), row.status(), onHand, reserved,
					Math.max(onHand - reserved, 0), locations));
		}

		return result;
	}

	private AdminProductResponse toResponse(
			ProductHeader header,
			List<AdminProductImageResponse> images,
			List<AdminProductVariantResponse> variants) {
		String minimumPrice = variants.stream()
				.filter(variant -> "active".equals(variant.status()))
				.map(AdminProductVariantResponse::price)
				.map(BigDecimal::new)
				.min(BigDecimal::compareTo)
				.map(this::money)
				.orElse("0.00");
		int totalOnHand = variants.stream()
				.mapToInt(AdminProductVariantResponse::onHandQuantity)
				.sum();
		int totalReserved = variants.stream()
				.mapToInt(AdminProductVariantResponse::reservedQuantity)
				.sum();

		return new AdminProductResponse(
				header.id(), header.itemId(), header.status(), header.name(),
				header.categoryId(), header.category(), header.brandId(), header.brand(),
				header.description(), images.isEmpty() ? null : images.getFirst().url(), images,
				minimumPrice, totalOnHand, totalReserved,
				Math.max(totalOnHand - totalReserved, 0), variants,
				header.createdAt().toInstant(), header.updatedAt().toInstant());
	}

	private ProductHeader mapHeader(ResultSet row, int rowNumber) throws SQLException {
		return new ProductHeader(
				row.getString("id"),
				row.getString("item_id"),
				row.getString("status"),
				row.getString("name"),
				row.getLong("category_id"),
				row.getString("category_name"),
				row.getString("brand_id"),
				row.getString("brand_name"),
				row.getString("description"),
				row.getObject("created_at", OffsetDateTime.class),
				row.getObject("updated_at", OffsetDateTime.class));
	}

	private String money(BigDecimal value) {
		return value.setScale(2).toPlainString();
	}

	public static String resolveSortColumn(String sortField) {
		return SORT_COLUMNS.get(sortField);
	}

	public record IdPage(List<String> ids, long totalElements) {
	}

	private record ProductHeader(
			String id,
			String itemId,
			String status,
			String name,
			Long categoryId,
			String category,
			String brandId,
			String brand,
			String description,
			OffsetDateTime createdAt,
			OffsetDateTime updatedAt) {
	}

	private record VariantRow(
			String id,
			String sku,
			String color,
			String size,
			String specification,
			BigDecimal price,
			String status) {
	}
}
