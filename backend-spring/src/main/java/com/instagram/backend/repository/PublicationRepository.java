package com.instagram.backend.repository;

import com.instagram.backend.model.Publication;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

import java.util.UUID;

@Repository
public interface PublicationRepository extends ReactiveCrudRepository<Publication, Integer> {
    
    Flux<Publication> findAllByOrderByCreatedAtDesc();
    
    Flux<Publication> findAllByUserIdOrderByCreatedAtDesc(UUID userId);
}
