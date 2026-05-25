package com.instagram.backend.repository;

import com.instagram.backend.model.Profile;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface ProfileRepository extends ReactiveCrudRepository<Profile, UUID> {
    reactor.core.publisher.Mono<Profile> findByUsername(String username);
}
