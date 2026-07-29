package com.yuruicamp.backend.catalog.application;

import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

import com.yuruicamp.backend.catalog.api.AdminEquipmentSpecItemRequest;
import com.yuruicamp.backend.catalog.api.AdminEquipmentSpecItemResponse;
import com.yuruicamp.backend.catalog.api.AdminEquipmentSpecsRequest;
import com.yuruicamp.backend.catalog.api.AdminEquipmentSpecsResponse;
import com.yuruicamp.backend.catalog.api.AdminEquipmentTagsRequest;
import com.yuruicamp.backend.catalog.api.AdminEquipmentTagsResponse;
import com.yuruicamp.backend.catalog.infrastructure.AdminEquipmentAttributeRepository;
import com.yuruicamp.backend.catalog.infrastructure.AdminEquipmentAttributeRepository.SpecRow;
import com.yuruicamp.backend.catalog.infrastructure.EquipmentItemRepository;
import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 依 {@code itemId} 維護裝備規格／標籤（W2-04）。
 * Admin equipment specs/tags use-cases, keyed by {@code equipment_items.id}.
 *
 * <p><b>與商城 Products PUT／租借 Rentals PUT 的分工（契約定案，避免互相覆蓋）</b>：
 * {@code AdminProductService}／{@code AdminRentalService} 的 Request DTO
 * 完全沒有宣告 specs／tags 欄位，所以那兩支 PUT 永遠不會寫
 * {@code equipment_specifications}／{@code equipment_tags}。這兩張表<b>只有這支
 * Service（也就是這裡的兩個 dedicated endpoint）會寫</b>，不存在「兩邊都能改
 * 同一張表、要比最後寫入時間」的情境，所以不需要 last-write-wins：
 * 用「單一寫入入口」直接排除衝突，而不是靠時間戳仲裁。</p>
 */
@Service
public class AdminEquipmentItemService {

	private final EquipmentItemRepository equipmentItemRepository;
	private final AdminEquipmentAttributeRepository attributeRepository;

	public AdminEquipmentItemService(
			EquipmentItemRepository equipmentItemRepository,
			AdminEquipmentAttributeRepository attributeRepository) {
		this.equipmentItemRepository = equipmentItemRepository;
		this.attributeRepository = attributeRepository;
	}

	@Transactional(readOnly = true)
	public AdminEquipmentSpecsResponse getSpecs(String itemId) {
		requireItem(itemId);

		return toSpecsResponse(itemId, attributeRepository.findSpecs(itemId));
	}

	/**
	 * 整組取代規格：request 出現的 key → upsert；DB 有但沒出現的 key → 刪除（本表沒有
	 * active 欄位可軟停用，所以「沒出現」就是真的刪除，跟契約文件寫的規則一致）。
	 */
	@Transactional
	public AdminEquipmentSpecsResponse replaceSpecs(String itemId, AdminEquipmentSpecsRequest request) {
		requireItem(itemId);
		List<AdminEquipmentSpecItemRequest> items = request.specs() == null ? List.of() : request.specs();

		// 用 LinkedHashMap 保留 request 原本的順序；同一個 key 重複出現視為使用者打錯，直接 400，
		// 不要靜默丟掉其中一筆讓管理員誤以為兩筆都存了。
		Map<String, String> desired = new LinkedHashMap<>();
		for (AdminEquipmentSpecItemRequest item : items) {
			String key = item.key().trim();
			String value = item.value().trim();
			if (desired.containsKey(key)) {
				throw validation("Duplicate spec key in request: " + key);
			}
			desired.put(key, value);
		}

		Instant now = Instant.now();
		attributeRepository.deleteAllSpecs(itemId);
		desired.forEach((key, value) -> attributeRepository.insertSpec(itemId, key, value, now));

		return toSpecsResponse(itemId, attributeRepository.findSpecs(itemId));
	}

	@Transactional(readOnly = true)
	public AdminEquipmentTagsResponse getTags(String itemId) {
		requireItem(itemId);

		return new AdminEquipmentTagsResponse(itemId, attributeRepository.findTags(itemId));
	}

	/**
	 * 整組取代標籤：大小寫視為同一個標籤（對齊 DB 的
	 * {@code UNIQUE (item_id, lower(btrim(tag)))}），重複時後端自動去重、
	 * 保留第一次出現的原始大小寫（跟會員標籤指派「重複 id 視為同一個」的慣例一致）。
	 */
	@Transactional
	public AdminEquipmentTagsResponse replaceTags(String itemId, AdminEquipmentTagsRequest request) {
		requireItem(itemId);
		List<String> rawTags = request.tags() == null ? List.of() : request.tags();

		Map<String, String> desiredByNormalized = new LinkedHashMap<>();
		for (String rawTag : rawTags) {
			String trimmed = rawTag == null ? "" : rawTag.trim();
			if (trimmed.isBlank()) {
				throw validation("Tag must not be blank");
			}
			if (trimmed.length() > 100) {
				throw validation("Tag must be at most 100 characters: " + trimmed);
			}
			String normalized = trimmed.toLowerCase(Locale.ROOT);
			desiredByNormalized.putIfAbsent(normalized, trimmed);
		}

		Instant now = Instant.now();
		attributeRepository.deleteAllTags(itemId);
		desiredByNormalized.values().forEach(tag -> attributeRepository.insertTag(itemId, tag, now));

		return new AdminEquipmentTagsResponse(itemId, attributeRepository.findTags(itemId));
	}

	private void requireItem(String itemId) {
		if (!equipmentItemRepository.existsById(itemId)) {
			throw new BusinessException(ErrorCode.NOT_FOUND, "Equipment item not found: " + itemId);
		}
	}

	private AdminEquipmentSpecsResponse toSpecsResponse(String itemId, List<SpecRow> rows) {
		List<AdminEquipmentSpecItemResponse> specs = new ArrayList<>();
		rows.forEach(row -> specs.add(new AdminEquipmentSpecItemResponse(row.key(), row.value())));

		return new AdminEquipmentSpecsResponse(itemId, specs);
	}

	private BusinessException validation(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
