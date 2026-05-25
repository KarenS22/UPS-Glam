package com.instagram.backend.repository;

import com.instagram.backend.model.Comment;
import org.springframework.data.r2dbc.repository.Query;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Repository
public interface CommentRepository extends ReactiveCrudRepository<Comment, Integer> {
    
    Flux<Comment> findAllByPublicationIdOrderByCreatedAtAsc(Integer publicationId);

    @Query("DELETE FROM comments WHERE publication_id = :publicationId")
    Mono<Void> deleteAllByPublicationId(Integer publicationId);
}
