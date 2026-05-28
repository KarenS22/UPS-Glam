package com.instagram.backend.controller;

import com.instagram.backend.dto.AuthResponse;
import com.instagram.backend.dto.LoginRequest;
import com.instagram.backend.dto.RegisterRequest;
import com.instagram.backend.model.Profile;
import com.instagram.backend.repository.ProfileRepository;
import com.instagram.backend.service.SupabaseAuthService;
import com.instagram.backend.service.SupabaseStorageService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.MediaType;
import org.springframework.http.codec.multipart.FilePart;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final SupabaseAuthService authService;
    private final ProfileRepository profileRepository;
    private final SupabaseStorageService storageService;

    @PostMapping("/register")
    public Mono<Profile> register(@Valid @RequestBody RegisterRequest request) {
        log.info("Register request received for username: {}", request.getUsername());
        return authService.register(request);
    }

    @PostMapping("/login")
    public Mono<AuthResponse> login(@Valid @RequestBody LoginRequest request) {
        log.info("Login request received for email: {}", request.getEmail());
        return authService.login(request);
    }

    @GetMapping("/me")
    public Mono<Profile> getCurrentUser() {
        return ReactiveSecurityContextHolder.getContext()
                .flatMap(ctx -> {
                    UUID userId = (UUID) ctx.getAuthentication().getPrincipal();
                    log.info("Fetching profile for currently authenticated user UUID: {}", userId);
                    return profileRepository.findById(userId);
                });
    }

    @PutMapping(value = "/profile", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Mono<Profile> updateProfile(
            @RequestPart(value = "username", required = false) String username,
            @RequestPart(value = "fullName", required = false) String fullName,
            @RequestPart(value = "avatar", required = false) FilePart avatarPart) {
        
        log.info("Profile update request received. Username: {}, FullName: {}, HasAvatarPart: {}", 
                username, fullName, avatarPart != null);

        return ReactiveSecurityContextHolder.getContext()
                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                .flatMap(userId -> profileRepository.findById(userId)
                        .flatMap(profile -> {
                            Mono<Profile> checkUsernameMono;
                            if (username != null && !username.trim().isEmpty() && !username.trim().equalsIgnoreCase(profile.getUsername())) {
                                String newUsername = username.trim().toLowerCase();
                                checkUsernameMono = profileRepository.findByUsername(newUsername)
                                        .flatMap(existing -> Mono.<Profile>error(new org.springframework.web.server.ResponseStatusException(
                                                org.springframework.http.HttpStatus.BAD_REQUEST, "El nombre de usuario ya está en uso."
                                        )))
                                        .defaultIfEmpty(profile)
                                        .map(p -> {
                                            p.setUsername(newUsername);
                                            return p;
                                        });
                            } else {
                                checkUsernameMono = Mono.just(profile);
                            }

                            return checkUsernameMono.flatMap(p -> {
                                if (fullName != null && !fullName.trim().isEmpty()) {
                                    p.setFullName(fullName.trim());
                                }

                                if (avatarPart != null && !avatarPart.filename().isEmpty()) {
                                    return filePartToBytes(avatarPart)
                                            .flatMap(bytes -> {
                                                String extension = getFileExtension(avatarPart.filename());
                                                String fileName = "avatars/" + storageService.generateUniqueFileName(extension);
                                                return storageService.uploadImage(bytes, fileName, "image/jpeg")
                                                        .flatMap(url -> {
                                                            p.setAvatarUrl(url);
                                                            return profileRepository.save(p);
                                                        });
                                            });
                                } else {
                                    return profileRepository.save(p);
                                }
                            });
                        })
                );
    }

    private Mono<byte[]> filePartToBytes(FilePart filePart) {
        return filePart.content()
                .map(dataBuffer -> {
                    byte[] bytes = new byte[dataBuffer.readableByteCount()];
                    dataBuffer.read(bytes);
                    DataBufferUtils.release(dataBuffer);
                    return bytes;
                })
                .collectList()
                .map(list -> {
                    int totalSize = list.stream().mapToInt(b -> b.length).sum();
                    byte[] result = new byte[totalSize];
                    int offset = 0;
                    for (byte[] block : list) {
                        System.arraycopy(block, 0, result, offset, block.length);
                        offset += block.length;
                    }
                    return result;
                });
    }

    private String getFileExtension(String filename) {
        if (filename == null || !filename.contains(".")) {
            return ".jpg";
        }
        return filename.substring(filename.lastIndexOf("."));
    }
}
