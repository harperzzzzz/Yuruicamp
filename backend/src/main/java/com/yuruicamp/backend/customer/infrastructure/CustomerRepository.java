package com.yuruicamp.backend.customer.infrastructure;

import java.util.Optional;

import com.yuruicamp.backend.customer.domain.Customer;

import org.springframework.data.jpa.repository.JpaRepository;

public interface CustomerRepository extends JpaRepository<Customer, String> {

	Optional<Customer> findByFirebaseUid(String firebaseUid);

	Optional<Customer> findByEmailIgnoreCase(String email);
}
