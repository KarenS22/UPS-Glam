package com.instagram.backend.dto;

import com.instagram.backend.model.Profile;
import com.instagram.backend.model.Publication;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PublicationFeedDto {
    private Publication publication;
    private Profile creator;
    private Long likesCount;
    private Boolean isLikedByMe;
}
