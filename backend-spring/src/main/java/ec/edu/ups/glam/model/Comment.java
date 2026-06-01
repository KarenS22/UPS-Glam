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
@Table("comments")
public class Comment {

    @Id
    private Integer id;

    @Column("publication_id")
    private Integer publicationId;

    @Column("user_id")
    private UUID userId;

    private String content;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();
}
