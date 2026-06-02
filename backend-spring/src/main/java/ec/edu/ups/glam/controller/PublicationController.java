package ec.edu.ups.glam.controller;

import ec.edu.ups.glam.dto.PublicationFeedDto;
import ec.edu.ups.glam.model.Profile;
import ec.edu.ups.glam.model.Publication;
import ec.edu.ups.glam.repository.CommentRepository;
import ec.edu.ups.glam.repository.LikeRepository;
import ec.edu.ups.glam.repository.ProfileRepository;
import ec.edu.ups.glam.repository.PublicationRepository;
import ec.edu.ups.glam.service.SupabaseStorageService;
import ec.edu.ups.glam.dto.ProcessedPublicationRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.MediaType;
import org.springframework.http.codec.multipart.FilePart;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/publications")
@RequiredArgsConstructor
public class PublicationController {

        private final PublicationRepository publicationRepository;
        private final ProfileRepository profileRepository;
        private final LikeRepository likeRepository;
        private final CommentRepository commentRepository;
        private final SupabaseStorageService storageService;

        @PostMapping("/processed")
        public Mono<Publication> createProcessedPublication(@RequestBody ProcessedPublicationRequest request) {
                log.info("Creating a processed publication with filter: {}", request.getFilterApplied());

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(userId -> {
                                        Publication publication = Publication.builder()
                                                        .userId(userId)
                                                        .caption(request.getCaption())
                                                        .imageUrl(request.getImageUrl())
                                                        .processedImageUrl(request.getProcessedImageUrl())
                                                        .filterApplied(request.getFilterApplied())
                                                        .build();

                                        log.info("Saving publication details with GPU filter to database for user: {}",
                                                        userId);
                                        return publicationRepository.save(publication);
                                });
        }

        @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
        public Mono<Publication> createPublication(
                        @RequestPart("file") FilePart filePart,
                        @RequestPart(value = "caption", required = false) String caption) {

                log.info("Creating a new publication with caption: {}", caption);

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(userId ->
                                // Convert reactive stream of file buffers into simple byte array
                                filePartToBytes(filePart)
                                                .flatMap(bytes -> {
                                                        String extension = getFileExtension(filePart.filename());
                                                        String fileName = "publications/" + storageService
                                                                        .generateUniqueFileName(extension);

                                                        return storageService.uploadImage(bytes, fileName, "image/jpeg")
                                                                        .flatMap(url -> {
                                                                                Publication publication = Publication
                                                                                                .builder()
                                                                                                .userId(userId)
                                                                                                .caption(caption)
                                                                                                .imageUrl(url)
                                                                                                .build();

                                                                                log.info("Saving publication details to database for user: {}",
                                                                                                userId);
                                                                                return publicationRepository
                                                                                                .save(publication);
                                                                        });
                                                }));
        }

        @GetMapping("/feed")
        public Flux<PublicationFeedDto> getFeed() {
                log.info("Fetching global publications feed reactive-style");

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMapMany(currentUserId -> publicationRepository
                                                .findAllByOrderByCreatedAtDescIdDesc()
                                                .flatMapSequential(pub -> {
                                                        Mono<Profile> creatorMono = profileRepository
                                                                        .findById(pub.getUserId())
                                                                        .defaultIfEmpty(new Profile(pub.getUserId(),
                                                                                        "deleted_user", "Deleted User",
                                                                                        null,
                                                                                        null, false));
                                                        Mono<Long> likesCountMono = likeRepository
                                                                        .countByPublicationId(pub.getId());
                                                        Mono<Long> commentsCountMono = commentRepository
                                                                        .countByPublicationId(pub.getId());
                                                        Mono<Boolean> likedByMeMono = likeRepository
                                                                        .existsByPublicationIdAndUserId(pub.getId(),
                                                                                        currentUserId);

                                                        // Zip all data points to compile a unified feed DTO
                                                        return Mono.zip(creatorMono, likesCountMono, commentsCountMono,
                                                                        likedByMeMono)
                                                                        .map(tuple -> PublicationFeedDto.builder()
                                                                                        .publication(pub)
                                                                                        .creator(tuple.getT1())
                                                                                        .likesCount(tuple.getT2())
                                                                                        .commentsCount(tuple.getT3())
                                                                                        .isLikedByMe(tuple.getT4())
                                                                                        .build());
                                                }));
        }

        @GetMapping("/user/{userId}")
        public Flux<PublicationFeedDto> getUserPublications(@PathVariable UUID userId) {
                log.info("Fetching publication history with social details for user: {}", userId);

                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMapMany(currentUserId -> publicationRepository
                                                .findAllByUserIdOrderByCreatedAtDescIdDesc(userId)
                                                .flatMapSequential(pub -> {
                                                        Mono<Profile> creatorMono = profileRepository
                                                                        .findById(pub.getUserId())
                                                                        .defaultIfEmpty(new Profile(pub.getUserId(),
                                                                                        "deleted_user", "Deleted User",
                                                                                        null,
                                                                                        null, false));
                                                        Mono<Long> likesCountMono = likeRepository
                                                                        .countByPublicationId(pub.getId());
                                                        Mono<Long> commentsCountMono = commentRepository
                                                                        .countByPublicationId(pub.getId());
                                                        Mono<Boolean> likedByMeMono = likeRepository
                                                                        .existsByPublicationIdAndUserId(pub.getId(),
                                                                                        currentUserId);

                                                        return Mono.zip(creatorMono, likesCountMono, commentsCountMono,
                                                                        likedByMeMono)
                                                                        .map(tuple -> PublicationFeedDto.builder()
                                                                                        .publication(pub)
                                                                                        .creator(tuple.getT1())
                                                                                        .likesCount(tuple.getT2())
                                                                                        .commentsCount(tuple.getT3())
                                                                                        .isLikedByMe(tuple.getT4())
                                                                                        .build());
                                                }));
        }

        @org.springframework.transaction.annotation.Transactional
        @DeleteMapping("/{id}")
        public Mono<Void> deletePublication(@PathVariable Integer id) {
                log.info("Request to delete publication: {}", id);
                return ReactiveSecurityContextHolder.getContext()
                                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                                .flatMap(currentUserId -> publicationRepository.findById(id)
                                                .flatMap(pub -> {
                                                        if (pub.getUserId().equals(currentUserId)) {
                                                                log.info("Deleting publication {} by owner {}", id,
                                                                                currentUserId);
                                                                // 1. Delete comments and likes first to avoid
                                                                // referential integrity errors
                                                                Mono<Void> deleteComments = commentRepository
                                                                                .deleteAllByPublicationId(pub.getId());
                                                                Mono<Void> deleteLikes = likeRepository
                                                                                .deleteAllByPublicationId(pub.getId());
                                                                // 2. Delete original and processed images from storage
                                                                Mono<Void> deleteOriginalImage = storageService
                                                                                .deleteImage(pub.getImageUrl());
                                                                Mono<Void> deleteProcessedImage = pub
                                                                                .getProcessedImageUrl() != null
                                                                                && !pub.getProcessedImageUrl().isEmpty()
                                                                                                ? storageService.deleteImage(
                                                                                                                pub.getProcessedImageUrl())
                                                                                                : Mono.empty();
                                                                // 3. Delete publication
                                                                Mono<Void> deletePub = publicationRepository
                                                                                .deleteById(pub.getId());
                                                                // Chain everything: relations, storage, then parent
                                                                // entity
                                                                return Mono.when(deleteComments, deleteLikes)
                                                                                .then(Mono.when(deleteOriginalImage,
                                                                                                deleteProcessedImage))
                                                                                .then(deletePub);
                                                        } else {
                                                                return Mono.error(
                                                                                new org.springframework.web.server.ResponseStatusException(
                                                                                                org.springframework.http.HttpStatus.FORBIDDEN,
                                                                                                "No está autorizado para eliminar esta publicación."));
                                                        }
                                                }))
                                .then();
        }

        /**
         * Helper to read reactive FilePart content and assemble a linear byte array.
         */
        private Mono<byte[]> filePartToBytes(FilePart filePart) {
                return filePart.content()
                                .map(dataBuffer -> {
                                        byte[] bytes = new byte[dataBuffer.readableByteCount()];
                                        dataBuffer.read(bytes);
                                        DataBufferUtils.release(dataBuffer); // Release buffer to avoid VRAM/RAM leaks
                                        return bytes;
                                })
                                .collectList()
                                .map(list -> {
                                        int totalSize = list.stream().mapToInt(b -> b.length).sum();
                                        byte[] result = new byte[totalSize];
                                        int offset = 0;
                                        for (byte[] block : list) {
                                                System.arraycopy(block, 0, result, offset, block.length);
                                                offset += block.length;
                                        }
                                        return result;
                                });
        }

        private String getFileExtension(String filename) {
                if (filename == null || !filename.contains(".")) {
                        return ".jpg";
                }
                return filename.substring(filename.lastIndexOf("."));
        }
}
