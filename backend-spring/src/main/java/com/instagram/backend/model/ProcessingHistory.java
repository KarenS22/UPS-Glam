package com.instagram.backend.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Column;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("processing_history")
public class ProcessingHistory {

    @Id
    private Integer id;

    @Column("user_id")
    private UUID userId;

    @Column("original_image_url")
    private String originalImageUrl;

    @Column("processed_image_url")
    private String processedImageUrl;

    @Column("filter_id")
    private String filterId;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();
}
