package com.yuruicamp.backend.inventory.infrastructure;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.yuruicamp.backend.inventory.api.AdminInventoryConversionResponse;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

/**
 * ADM-W2-05 跨領域庫存轉換（商城→租借）資料存取。
 * 只負責 {@code inventory_conversions} 配對紀錄本身；成對的兩張
 * {@code inventory_movements} 表頭與庫存鎖定／加減仍重用
 * {@link AdminInventoryMovementRepository}，避免重複實作 G-3 已驗證過的鎖定順序與 SQL。
 */
@Repository
public class AdminInventoryConversionRepository {

	private final NamedParameterJdbcTemplate jdbc;

	public AdminInventoryConversionRepository(NamedParameterJdbcTemplate jdbc) {
		this.jdbc = jdbc;
	}

	public IdPage findIds(int page, int size, String status) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("limit", size)
				.addValue("offset", page * size);
		StringBuilder where = new StringBuilder(" WHERE 1 = 1 ");
		if (!status.isBlank()) {
			where.append(" AND source_movement.status = :status ");
			parameters.addValue("status", status);
		}
		String from = """
				FROM inventory_conversions conversion
				JOIN inventory_movements source_movement ON source_movement.id = conversion.source_movement_id
				""" + where;

		long totalElements = jdbc.queryForObject("SELECT count(*) " + from, parameters, Long.class);
		List<Long> ids = jdbc.queryForList(
				"SELECT conversion.id " + from
						+ " ORDER BY conversion.created_at DESC, conversion.id DESC"
						+ " LIMIT :limit OFFSET :offset",
				parameters,
				Long.class);

		return new IdPage(ids, totalElements);
	}

	public List<AdminInventoryConversionResponse> findByIds(List<Long> ids) {
		if (ids.isEmpty()) {
			return List.of();
		}
		MapSqlParameterSource parameters = new MapSqlParameterSource("ids", ids);
		Map<Long, AdminInventoryConversionResponse> byId = new HashMap<>();
		jdbc.query("""
				SELECT conversion.id AS id, conversion.idempotency_key AS idempotency_key, conversion.quantity AS quantity,
				       conversion.source_location_id, source_location.name AS source_location_name,
				       conversion.destination_location_id, destination_location.name AS destination_location_name,
				       conversion.source_variant_id, source_variant.sku AS source_variant_sku,
				       source_item.name AS source_variant_name,
				       conversion.destination_rental_variant_id, dest_variant.sku AS destination_variant_sku,
				       dest_item.name AS destination_variant_name,
				       source_movement.id AS source_movement_id, source_movement.movement_no AS source_movement_no,
				       source_movement.status AS status, source_movement.reason AS reason,
				       source_movement.employee_id AS employee_id, employee.name AS employee_name,
				       source_movement.occurred_at AS occurred_at, source_movement.posted_at AS posted_at,
				       source_movement.created_at AS created_at,
				       destination_movement.id AS destination_movement_id,
				       destination_movement.movement_no AS destination_movement_no
				FROM inventory_conversions conversion
				JOIN inventory_movements source_movement ON source_movement.id = conversion.source_movement_id
				JOIN inventory_movements destination_movement ON destination_movement.id = conversion.destination_movement_id
				JOIN inventory_locations source_location ON source_location.id = conversion.source_location_id
				JOIN inventory_locations destination_location ON destination_location.id = conversion.destination_location_id
				JOIN product_variants source_variant ON source_variant.id = conversion.source_variant_id
				JOIN products source_product ON source_product.id = source_variant.product_id
				JOIN equipment_items source_item ON source_item.id = source_product.item_id
				JOIN rental_sku_variants dest_variant ON dest_variant.id = conversion.destination_rental_variant_id
				JOIN rental_skus dest_sku ON dest_sku.id = dest_variant.rental_sku_id
				JOIN equipment_items dest_item ON dest_item.id = dest_sku.item_id
				JOIN admin_users employee ON employee.id = source_movement.employee_id
				WHERE conversion.id IN (:ids)
				""", parameters, (org.springframework.jdbc.core.RowCallbackHandler) row -> byId.put(
				row.getLong("id"),
				mapResponse(row)));

		List<AdminInventoryConversionResponse> result = new ArrayList<>();
		for (Long id : ids) {
			AdminInventoryConversionResponse response = byId.get(id);
			if (response != null) {
				result.add(response);
			}
		}

		return result;
	}

	/** 悲觀鎖定轉換配對本身，回傳兩端異動單 ID／規格／地點／數量供 Service 決策。 */
	public ConversionRecord lockConversion(long id) {
		List<ConversionRecord> rows = jdbc.query("""
				SELECT id, source_movement_id, destination_movement_id,
				       source_variant_id, destination_rental_variant_id,
				       source_location_id, destination_location_id, quantity
				FROM inventory_conversions
				WHERE id = :id
				FOR UPDATE
				""", new MapSqlParameterSource("id", id), this::mapRecord);

		return rows.isEmpty() ? null : rows.getFirst();
	}

	/** 依冪等鍵查詢既有轉換（不加鎖；真正防重仍靠 idempotency_key UNIQUE 約束）。 */
	public ConversionRecord findByIdempotencyKey(String idempotencyKey) {
		List<ConversionRecord> rows = jdbc.query("""
				SELECT id, source_movement_id, destination_movement_id,
				       source_variant_id, destination_rental_variant_id,
				       source_location_id, destination_location_id, quantity
				FROM inventory_conversions
				WHERE idempotency_key = :idempotencyKey
				""", new MapSqlParameterSource("idempotencyKey", idempotencyKey), this::mapRecord);

		return rows.isEmpty() ? null : rows.getFirst();
	}

	public long insertConversion(
			long sourceMovementId,
			long destinationMovementId,
			String sourceVariantId,
			String destinationRentalVariantId,
			String sourceLocationId,
			String destinationLocationId,
			int quantity,
			String idempotencyKey,
			Instant now) {
		MapSqlParameterSource parameters = new MapSqlParameterSource()
				.addValue("sourceMovementId", sourceMovementId)
				.addValue("destinationMovementId", destinationMovementId)
				.addValue("sourceVariantId", sourceVariantId)
				.addValue("destinationRentalVariantId", destinationRentalVariantId)
				.addValue("sourceLocationId", sourceLocationId)
				.addValue("destinationLocationId", destinationLocationId)
				.addValue("quantity", quantity)
				.addValue("idempotencyKey", idempotencyKey)
				.addValue("now", OffsetDateTime.ofInstant(now, java.time.ZoneOffset.UTC));

		return jdbc.queryForObject("""
				INSERT INTO inventory_conversions (
				    source_movement_id, destination_movement_id,
				    source_variant_id, destination_rental_variant_id,
				    source_location_id, destination_location_id,
				    quantity, idempotency_key, created_at)
				VALUES (
				    :sourceMovementId, :destinationMovementId,
				    :sourceVariantId, :destinationRentalVariantId,
				    :sourceLocationId, :destinationLocationId,
				    :quantity, :idempotencyKey, :now)
				RETURNING id
				""", parameters, Long.class);
	}

	private ConversionRecord mapRecord(ResultSet row, int rowNumber) throws SQLException {
		return new ConversionRecord(
				row.getLong("id"),
				row.getLong("source_movement_id"),
				row.getLong("destination_movement_id"),
				row.getString("source_variant_id"),
				row.getString("destination_rental_variant_id"),
				row.getString("source_location_id"),
				row.getString("destination_location_id"),
				row.getInt("quantity"));
	}

	private AdminInventoryConversionResponse mapResponse(ResultSet row) throws SQLException {
		return new AdminInventoryConversionResponse(
				row.getLong("id"),
				row.getString("idempotency_key"),
				row.getString("status"),
				row.getInt("quantity"),
				row.getString("reason"),
				row.getString("source_location_id"),
				row.getString("source_location_name"),
				row.getString("destination_location_id"),
				row.getString("destination_location_name"),
				row.getString("source_variant_id"),
				row.getString("source_variant_sku"),
				row.getString("source_variant_name"),
				row.getString("destination_rental_variant_id"),
				row.getString("destination_variant_sku"),
				row.getString("destination_variant_name"),
				row.getLong("source_movement_id"),
				row.getString("source_movement_no"),
				row.getLong("destination_movement_id"),
				row.getString("destination_movement_no"),
				row.getString("employee_id"),
				row.getString("employee_name"),
				toInstant(row, "occurred_at"),
				toInstant(row, "posted_at"),
				toInstant(row, "created_at"));
	}

	private Instant toInstant(ResultSet row, String column) throws SQLException {
		OffsetDateTime value = row.getObject(column, OffsetDateTime.class);

		return value == null ? null : value.toInstant();
	}

	public record IdPage(List<Long> ids, long totalElements) {
	}

	public record ConversionRecord(
			long id,
			long sourceMovementId,
			long destinationMovementId,
			String sourceVariantId,
			String destinationRentalVariantId,
			String sourceLocationId,
			String destinationLocationId,
			int quantity) {
	}
}
