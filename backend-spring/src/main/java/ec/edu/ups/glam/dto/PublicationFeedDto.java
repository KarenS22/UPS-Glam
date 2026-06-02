package ec.edu.ups.glam.dto;

import ec.edu.ups.glam.model.Profile;
import ec.edu.ups.glam.model.Publication;
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
    private Long commentsCount;
    private Boolean isLikedByMe;
}
