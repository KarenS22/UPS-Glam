package ec.edu.ups.glam.repository;

import ec.edu.ups.glam.model.Publication;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;

import java.util.UUID;

@Repository
public interface PublicationRepository extends ReactiveCrudRepository<Publication, Integer> {

    Flux<Publication> findAllByOrderByCreatedAtDescIdDesc();

    Flux<Publication> findAllByUserIdOrderByCreatedAtDescIdDesc(UUID userId);
}
