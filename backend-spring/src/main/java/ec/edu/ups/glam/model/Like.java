package ec.edu.ups.glam.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Transient;
import org.springframework.data.domain.Persistable;
import org.springframework.data.relational.core.mapping.Column;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("likes")
public class Like implements Persistable<String> {

    @Column("publication_id")
    private Integer publicationId;

    @Column("user_id")
    private UUID userId;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Override
    @Transient
    public String getId() {
        return publicationId + "_" + userId;
    }

    @Override
    @Transient
    public boolean isNew() {
        return true; // Since we only insert likes (and delete them directly), it should always perform INSERT
    }
}
