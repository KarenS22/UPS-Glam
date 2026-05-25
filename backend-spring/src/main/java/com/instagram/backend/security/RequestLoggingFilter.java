package com.instagram.backend.security;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.annotation.Order;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.server.ServerWebExchange;
import org.springframework.web.server.WebFilter;
import org.springframework.web.server.WebFilterChain;
import reactor.core.publisher.Mono;

import java.time.Instant;

@Slf4j
@Component
@Order(-10) // Run early in the web filter chain
@RequiredArgsConstructor
public class RequestLoggingFilter implements WebFilter {

    private final JwtTokenProvider tokenProvider;

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, WebFilterChain chain) {
        Instant start = Instant.now();
        String method = exchange.getRequest().getMethod().name();
        String path = exchange.getRequest().getURI().getPath();

        // Bypass verbose logs on internal health checking endpoints
        if (path.equals("/health") || path.equals("/api/health")) {
            return chain.filter(exchange);
        }

        String user = "Anonymous";
        try {
            String token = resolveToken(exchange);
            if (StringUtils.hasText(token) && tokenProvider.validateToken(token)) {
                user = tokenProvider.getAuthentication(token).getName();
            }
        } catch (Exception e) {
            // Safe fallback to Anonymous if token parsing fails
        }

        final String finalUser = user;
        log.info("--> REQUEST STARTED: {} {} by user: {}", method, path, finalUser);

        return chain.filter(exchange)
                .doOnSuccess(aVoid -> {
                    int status = exchange.getResponse().getStatusCode() != null ? 
                            exchange.getResponse().getStatusCode().value() : 200;
                    long duration = Instant.now().toEpochMilli() - start.toEpochMilli();
                    log.info("<-- REQUEST COMPLETED: {} {} -> STATUS {} ({} ms) for user: {}", 
                            method, path, status, duration, finalUser);
                })
                .doOnError(throwable -> {
                    long duration = Instant.now().toEpochMilli() - start.toEpochMilli();
                    log.error("<-- REQUEST FAILED: {} {} -> ERROR: {} ({} ms) for user: {}", 
                            method, path, throwable.getMessage(), duration, finalUser, throwable);
                });
    }

    private String resolveToken(ServerWebExchange exchange) {
        String bearerToken = exchange.getRequest().getHeaders().getFirst(HttpHeaders.AUTHORIZATION);
        if (StringUtils.hasText(bearerToken) && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
