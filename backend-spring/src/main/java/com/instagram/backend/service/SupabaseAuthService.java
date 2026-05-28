package com.instagram.backend.service;

import com.instagram.backend.dto.AuthResponse;
import com.instagram.backend.dto.LoginRequest;
import com.instagram.backend.dto.RegisterRequest;
import com.instagram.backend.model.Profile;
import com.instagram.backend.repository.ProfileRepository;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class SupabaseAuthService {

    private final WebClient webClient;
    private final ProfileRepository profileRepository;

    @Value("${supabase.url}")
    private String supabaseUrl;

    @Value("${supabase.anon-key}")
    private String supabaseAnonKey;

    /**
     * Proxies signup request to Supabase Auth and registers local user profile in PostgreSQL.
     */
    public Mono<Profile> register(RegisterRequest request) {
        String signupUrl = supabaseUrl + "/auth/v1/signup";
        log.info("Proxying registration to Supabase Auth: {}", signupUrl);

        Map<String, String> body = Map.of(
                "email", request.getEmail(),
                "password", request.getPassword()
        );

        return webClient.post()
                .uri(signupUrl)
                .header("apikey", supabaseAnonKey)
                .header("Authorization", "Bearer " + supabaseAnonKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .doOnError(org.springframework.web.reactive.function.client.WebClientResponseException.class, err -> {
                    log.error("Supabase Auth API responded with error status: {}, body: {}", 
                            err.getStatusCode(), err.getResponseBodyAsString());
                })
                .flatMap(node -> {
                    log.info("Supabase signup response: {}", node.toString());
                    // Extract user id from response
                    JsonNode userNode = node.get("user");
                    if (userNode == null || userNode.get("id") == null) {
                        return Mono.error(new RuntimeException("Registration failed: Invalid response from Auth provider: " + node.toString()));
                    }
                    
                    UUID userId = UUID.fromString(userNode.get("id").asText());
                    
                    Profile profile = Profile.builder()
                            .id(userId)
                            .username(request.getUsername())
                            .fullName(request.getFullName())
                            .avatarUrl(null)
                            .isNewRecord(true) // Crucial to perform R2DBC INSERT
                            .build();

                    log.info("Creating profile for registered user: {} with username: {}", userId, request.getUsername());
                    return profileRepository.save(profile);
                })
                .doOnError(err -> log.error("Failed to register user: {}", err.getMessage()));
    }

    /**
     * Authenticates with Supabase Auth, returning a valid JWT and the user's Profile.
     */
    public Mono<AuthResponse> login(LoginRequest request) {
        String loginUrl = supabaseUrl + "/auth/v1/token?grant_type=password";
        log.info("Proxying authentication to Supabase Auth: {}", loginUrl);

        Map<String, String> body = Map.of(
                "email", request.getEmail(),
                "password", request.getPassword()
        );

        return webClient.post()
                .uri(loginUrl)
                .header("apikey", supabaseAnonKey)
                .header("Authorization", "Bearer " + supabaseAnonKey)
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .doOnError(org.springframework.web.reactive.function.client.WebClientResponseException.class, err -> {
                    log.error("Supabase Auth API responded with error status: {}, body: {}", 
                            err.getStatusCode(), err.getResponseBodyAsString());
                })
                .flatMap(node -> {
                    String accessToken = node.get("access_token").asText();
                    long expiresIn = node.get("expires_in").asLong();
                    String tokenType = node.get("token_type").asText();
                    
                    UUID userId = UUID.fromString(node.get("user").get("id").asText());

                    log.info("Authentication successful for user: {}", userId);
                    
                    // Fetch profile matching this authenticated user ID
                    return profileRepository.findById(userId)
                            .map(profile -> AuthResponse.builder()
                                    .token(accessToken)
                                    .tokenType(tokenType)
                                    .expiresIn(expiresIn)
                                    .profile(profile)
                                    .build()
                            );
                })
                .doOnError(err -> log.error("Failed to login user: {}", err.getMessage()));
    }
}
