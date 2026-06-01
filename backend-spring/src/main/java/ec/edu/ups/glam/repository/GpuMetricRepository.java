package ec.edu.ups.glam.repository;

import ec.edu.ups.glam.model.GpuMetric;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Mono;

@Repository
public interface GpuMetricRepository extends ReactiveCrudRepository<GpuMetric, Integer> {
    
    Mono<GpuMetric> findByProcessingId(Integer processingId);
}
