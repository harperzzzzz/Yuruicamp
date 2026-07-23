package com.yuruicamp.backend.review.application;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.List;
import java.util.Locale;
import java.util.UUID;

import com.yuruicamp.backend.common.exception.BusinessException;
import com.yuruicamp.backend.common.exception.ErrorCode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

@Service
public class ReviewPhotoStorageService {

	static final long MAX_BYTES = 5L * 1024 * 1024;
	private final Path root;

	public ReviewPhotoStorageService(@Value("${yuruicamp.review-upload-dir:./data/uploads/reviews}") String root) {
		this.root = Path.of(root).toAbsolutePath().normalize();
	}

	public List<String> store(String customerId, long orderItemId, MultipartFile[] files) {
		if (files == null || files.length == 0 || files.length > 5) {
			throw invalid("Review photos must contain 1 to 5 files");
		}
		String customerSegment = safeSegment(customerId);
		Path directory = root.resolve(customerSegment).resolve(Long.toString(orderItemId)).normalize();
		if (!directory.startsWith(root)) {
			throw invalid("Invalid upload path");
		}
		try {
			Files.createDirectories(directory);
			return java.util.Arrays.stream(files)
					.map(file -> storeOne(file, directory, customerSegment, orderItemId))
					.toList();
		} catch (IOException error) {
			throw new BusinessException(ErrorCode.INTERNAL_ERROR, "Unable to store review photo");
		}
	}

	public void delete(List<String> urls) {
		for (String url : urls) {
			if (url == null || !url.startsWith("/assets/uploads/reviews/")) {
				continue;
			}
			String relative = url.substring("/assets/uploads/reviews/".length());
			Path file = root.resolve(relative).normalize();
			if (!file.startsWith(root)) {
				continue;
			}
			try {
				Files.deleteIfExists(file);
			} catch (IOException ignored) {
				// DB ownership and review state remain authoritative if local cleanup fails.
			}
		}
	}

	private String storeOne(MultipartFile file, Path directory, String customerSegment, long orderItemId) {
		try {
			byte[] bytes = file.getBytes();
			if (bytes.length == 0 || bytes.length > MAX_BYTES) {
				throw invalid("Each review photo must be between 1 byte and 5 MB");
			}
			String extension = detectExtension(bytes, file.getContentType());
			String filename = UUID.randomUUID().toString().replace("-", "") + "." + extension;
			Files.write(directory.resolve(filename), bytes, StandardOpenOption.CREATE_NEW);
			return "/assets/uploads/reviews/" + customerSegment + "/" + orderItemId + "/" + filename;
		} catch (IOException error) {
			throw new BusinessException(ErrorCode.INTERNAL_ERROR, "Unable to store review photo");
		}
	}

	private String detectExtension(byte[] bytes, String contentType) {
		String type = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
		if (type.equals("image/jpeg") && bytes.length >= 3
				&& (bytes[0] & 0xff) == 0xff && (bytes[1] & 0xff) == 0xd8 && (bytes[2] & 0xff) == 0xff) {
			return "jpg";
		}
		if (type.equals("image/png") && bytes.length >= 8
				&& (bytes[0] & 0xff) == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47) {
			return "png";
		}
		if (type.equals("image/webp") && bytes.length >= 12
				&& bytes[0] == 'R' && bytes[1] == 'I' && bytes[2] == 'F' && bytes[3] == 'F'
				&& bytes[8] == 'W' && bytes[9] == 'E' && bytes[10] == 'B' && bytes[11] == 'P') {
			return "webp";
		}
		throw invalid("Only valid JPEG, PNG, or WebP images are allowed");
	}

	private String safeSegment(String value) {
		String result = value == null ? "" : value.replaceAll("[^A-Za-z0-9_-]", "_");
		if (result.isBlank()) {
			throw invalid("Invalid customer identifier");
		}
		return result;
	}

	private BusinessException invalid(String message) {
		return new BusinessException(ErrorCode.VALIDATION_ERROR, message);
	}
}
