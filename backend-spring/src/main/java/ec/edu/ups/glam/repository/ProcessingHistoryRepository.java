package ec.edu.ups.glam.repository;

import ec.edu.ups.glam.model.ProcessingHistory;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

import reactor.core.publisher.Mono;

import java.util.UUID;

@Repository
public interface ProcessingHistoryRepository extends ReactiveCrudRepository<ProcessingHistory, Integer> {
    
    Flux<ProcessingHistory> findAllByUserIdOrderByCreatedAtDesc(UUID userId);
    Mono<ProcessingHistory> findFirstByProcessedImageUrl(String processedImageUrl);
}
