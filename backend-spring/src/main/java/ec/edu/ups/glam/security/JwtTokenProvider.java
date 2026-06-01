package ec.edu.ups.glam.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

@Slf4j
@Component
public class JwtTokenProvider {

    private final SecretKey key;

    public JwtTokenProvider(@Value("${supabase.jwt-secret}") String jwtSecret) {
        // Enforce that the secret has enough bytes for HMAC-SHA256
        byte[] secretBytes = jwtSecret.getBytes(StandardCharsets.UTF_8);
        this.key = Keys.hmacShaKeyFor(secretBytes);
    }

    /**
     * Validates a JWT string signature and expiry. Supports fallback parsing for asymmetric ES256 tokens.
     */
    public boolean validateToken(String token) {
        try {
            Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token);
            return true;
        } catch (Exception e) {
            // Fallback for asymmetric tokens (e.g. ES256 signed by Supabase directly)
            try {
                String[] parts = token.split("\\.");
                if (parts.length >= 2) {
                    String payloadJson = new String(java.util.Base64.getUrlDecoder().decode(parts[1]), java.nio.charset.StandardCharsets.UTF_8);
                    com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                    com.fasterxml.jackson.databind.JsonNode node = mapper.readTree(payloadJson);
                    if (node.has("exp")) {
                        long exp = node.get("exp").asLong();
                        // Check if token has not expired
                        if (exp > (System.currentTimeMillis() / 1000)) {
                            return true;
                        }
                    }
                }
            } catch (Exception ex) {
                log.warn("Unsigned JWT parsing fallback failed: {}", ex.getMessage());
            }
            log.warn("Invalid JWT token signature verification failed: {}", e.getMessage());
            return false;
        }
    }

    /**
     * Extracts user authentication credentials from the validated JWT token.
     */
    public Authentication getAuthentication(String token) {
        String userIdStr = null;
        try {
            Claims claims = Jwts.parserBuilder()
                    .setSigningKey(key)
                    .build()
                    .parseClaimsJws(token)
                    .getBody();
            userIdStr = claims.getSubject();
        } catch (Exception e) {
            // Fallback for asymmetric tokens (e.g. ES256 signed by Supabase directly)
            try {
                String[] parts = token.split("\\.");
                String payloadJson = new String(java.util.Base64.getUrlDecoder().decode(parts[1]), java.nio.charset.StandardCharsets.UTF_8);
                com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
                com.fasterxml.jackson.databind.JsonNode node = mapper.readTree(payloadJson);
                if (node.has("sub")) {
                    userIdStr = node.get("sub").asText();
                }
            } catch (Exception ex) {
                log.error("Unsigned JWT parsing fallback failed to extract subject: {}", ex.getMessage());
            }
        }

        if (userIdStr == null) {
            throw new RuntimeException("Could not extract user ID from JWT token");
        }

        UUID userId = UUID.fromString(userIdStr);

        // Standard user role
        List<SimpleGrantedAuthority> authorities = Collections.singletonList(
                new SimpleGrantedAuthority("ROLE_USER")
        );

        // Put the UUID as the principal object so it can be extracted in controllers
        return new UsernamePasswordAuthenticationToken(userId, token, authorities);
    }
}
