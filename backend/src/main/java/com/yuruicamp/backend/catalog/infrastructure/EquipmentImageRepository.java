package com.yuruicamp.backend.catalog.infrastructure;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

import com.yuruicamp.backend.catalog.domain.EquipmentImage;

import org.springframework.data.jpa.repository.JpaRepository;

public interface EquipmentImageRepository extends JpaRepository<EquipmentImage, EquipmentImage.Pk> {

	Optional<EquipmentImage> findByItemIdAndSortOrder(String itemId, int sortOrder);

	List<EquipmentImage> findByItemIdInAndSortOrder(Collection<String> itemIds, int sortOrder);
}
