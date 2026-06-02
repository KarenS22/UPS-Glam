package ec.edu.ups.glam.controller;

import ec.edu.ups.glam.dto.CommentDto;
import ec.edu.ups.glam.model.Comment;
import ec.edu.ups.glam.model.Like;
import ec.edu.ups.glam.repository.CommentRepository;
import ec.edu.ups.glam.repository.LikeRepository;
import ec.edu.ups.glam.repository.ProfileRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.Map;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/publications/{publicationId}")
@RequiredArgsConstructor
public class SocialController {

        private final LikeRepository likeRepository;
        private final CommentRepository commentRepository;
        private final ProfileRepository profileRepository;

        @PostMapping("/like")
        public Mono<Void> likePublication(@PathVariable Integer publicationId) {
                log.info("Liking publication ID: {}", publicationId);

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(userId -> {
                                        Like like = Like.builder()
                                                        .publicationId(publicationId)
                                                        .userId(userId)
                                                        .build();

                                        return likeRepository.save(like)
                                                        .onErrorResume(DataIntegrityViolationException.class, e -> {
                                                                log.debug("Duplicate like detected for publication {} and user {}, ignoring.",
                                                                                publicationId, userId);
                                                                return Mono.empty();
                                                        });
                                })
                                .then();
        }

        @DeleteMapping("/like")
        public Mono<Void> unlikePublication(@PathVariable Integer publicationId) {
                log.info("Unliking publication ID: {}", publicationId);

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(userId -> likeRepository.deleteByPublicationIdAndUserId(publicationId,
                                                userId));
        }

        @PostMapping("/comments")
        public Mono<Comment> addComment(
                        @PathVariable Integer publicationId,
                        @RequestBody Map<String, String> body) {

                String content = body.get("content");
                log.info("Adding comment to publication ID: {}, content size: {}", publicationId,
                                content != null ? content.length() : 0);

                if (content == null || content.trim().isEmpty()) {
                        return Mono.error(new IllegalArgumentException("Comment content cannot be empty"));
                }

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(userId -> {
                                        Comment comment = Comment.builder()
                                                        .publicationId(publicationId)
                                                        .userId(userId)
                                                        .content(content)
                                                        .build();

                                        return commentRepository.save(comment);
                                });
        }

        @GetMapping("/comments")
        public Flux<CommentDto> getComments(@PathVariable Integer publicationId) {
                log.info("Fetching comments for publication ID: {}", publicationId);

                return commentRepository.findAllByPublicationIdOrderByCreatedAtAsc(publicationId)
                                .flatMap(comment -> profileRepository.findById(comment.getUserId())
                                                .map(profile -> CommentDto.builder()
                                                                .comment(comment)
                                                                .user(profile)
                                                                .build()));
        }
}
