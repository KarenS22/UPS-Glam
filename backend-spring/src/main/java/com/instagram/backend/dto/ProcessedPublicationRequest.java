package com.instagram.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProcessedPublicationRequest {
    private String caption;
    private String imageUrl;
    private String processedImageUrl;
    private String filterApplied;
}
