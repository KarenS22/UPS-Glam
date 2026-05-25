package com.instagram.backend.repository;

import com.instagram.backend.model.Like;
import org.springframework.data.r2dbc.repository.Query;
import org.springframework.data.repository.reactive.ReactiveCrudRepository;
import org.springframework.stereotype.Repository;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Repository
public interface LikeRepository extends ReactiveCrudRepository<Like, String> {

    @Query("SELECT * FROM likes WHERE publication_id = :publicationId AND user_id = :userId")
    Mono<Like> findByPublicationIdAndUserId(Integer publicationId, UUID userId);

    @Query("DELETE FROM likes WHERE publication_id = :publicationId AND user_id = :userId")
    Mono<Void> deleteByPublicationIdAndUserId(Integer publicationId, UUID userId);

    @Query("DELETE FROM likes WHERE publication_id = :publicationId")
    Mono<Void> deleteAllByPublicationId(Integer publicationId);

    @Query("SELECT COUNT(*) FROM likes WHERE publication_id = :publicationId")
    Mono<Long> countByPublicationId(Integer publicationId);

    @Query("SELECT EXISTS(SELECT 1 FROM likes WHERE publication_id = :publicationId AND user_id = :userId)")
    Mono<Boolean> existsByPublicationIdAndUserId(Integer publicationId, UUID userId);
}
