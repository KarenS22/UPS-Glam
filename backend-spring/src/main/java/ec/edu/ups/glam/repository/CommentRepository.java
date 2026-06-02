package ec.edu.ups.glam.repository;

import ec.edu.ups.glam.model.Comment;
import org.springframework.data.domain.Pageable;
import org.springframework.data.r2dbc.repository.Query;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Repository
public interface CommentRepository extends ReactiveCrudRepository<Comment, Integer> {

    Flux<Comment> findAllByPublicationId(Integer publicationId, Pageable pageable);

    Mono<Long> countByPublicationId(Integer publicationId);

    @Query("DELETE FROM comments WHERE publication_id = :publicationId")
    Mono<Void> deleteAllByPublicationId(Integer publicationId);
}
