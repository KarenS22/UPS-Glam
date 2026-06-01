package ec.edu.ups.glam.model;

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
@Table("publications")
public class Publication {

    @Id
    private Integer id;

    @Column("user_id")
    private UUID userId;

    private String caption;

    @Column("image_url")
    private String imageUrl;

    @Column("processed_image_url")
    private String processedImageUrl;

    @Column("filter_applied")
    private String filterApplied;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();
}
