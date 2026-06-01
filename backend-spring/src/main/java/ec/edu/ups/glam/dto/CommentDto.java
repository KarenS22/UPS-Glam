package ec.edu.ups.glam.dto;

import ec.edu.ups.glam.model.Comment;
import ec.edu.ups.glam.model.Profile;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CommentDto {
    private Comment comment;
    private Profile user;
}
