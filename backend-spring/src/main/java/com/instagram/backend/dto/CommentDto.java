package com.instagram.backend.dto;

import com.instagram.backend.model.Comment;
import com.instagram.backend.model.Profile;
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
