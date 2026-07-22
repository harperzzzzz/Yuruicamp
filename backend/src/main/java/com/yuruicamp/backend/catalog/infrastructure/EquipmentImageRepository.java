package com.yuruicamp.backend.catalog.infrastructure;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import com.yuruicamp.backend.catalog.domain.EquipmentImage;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface EquipmentImageRepository extends JpaRepository<EquipmentImage, EquipmentImage.Pk> {

	Optional<EquipmentImage> findByItemIdAndSortOrder(String itemId, int sortOrder);

	List<EquipmentImage> findByItemIdInAndSortOrder(Collection<String> itemIds, int sortOrder);

	List<EquipmentImage> findByItemIdOrderBySortOrder(String itemId);

	@Modifying
	@Query("delete from EquipmentImage image where image.itemId = :itemId")
	void deleteAllByItemId(@Param("itemId") String itemId);
}
