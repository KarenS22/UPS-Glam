package com.instagram.backend.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
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
@Table("profiles")
public class Profile implements Persistable<UUID> {

    @Id
    private UUID id;

    private String username;

    @Column("full_name")
    private String fullName;

    @Column("avatar_url")
    private String avatarUrl;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();

    @Transient
    @Builder.Default
    private boolean isNewRecord = false;

    @Override
    public UUID getId() {
        return id;
    }

    @Override
    @Transient
    public boolean isNew() {
        return isNewRecord || id == null;
    }
}
