package ec.edu.ups.glam.exception;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.reactive.function.client.WebClientResponseException;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.bind.support.WebExchangeBindException;

import java.util.HashMap;
import java.util.Map;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @ExceptionHandler(WebClientResponseException.class)
    public ResponseEntity<Map<String, String>> handleWebClientResponseException(WebClientResponseException ex) {
        log.error("WebClientResponseException caught: status={}, body={}", ex.getStatusCode(), ex.getResponseBodyAsString());
        
        String friendlyMessage = "Error de comunicación con el proveedor de autenticación";
        try {
            String bodyStr = ex.getResponseBodyAsString();
            JsonNode node = objectMapper.readTree(bodyStr);
            if (node.has("msg")) {
                friendlyMessage = node.get("msg").asText();
            } else if (node.has("error_description")) {
                friendlyMessage = node.get("error_description").asText();
            } else if (node.has("message")) {
                friendlyMessage = node.get("message").asText();
            }
        } catch (Exception e) {
            log.warn("Failed to parse WebClientResponseException error body", e);
        }

        // Map specific Supabase/GoTrue error messages to Spanish for premium UX
        String lowerMsg = friendlyMessage.toLowerCase();
        if (lowerMsg.contains("invalid login credentials") || lowerMsg.contains("invalid_credentials")) {
            friendlyMessage = "Correo o contraseña incorrectos.";
        } else if (lowerMsg.contains("signup requires email verification") || lowerMsg.contains("email_not_confirmed")) {
            friendlyMessage = "El registro requiere verificar tu correo electrónico primero.";
        } else if (lowerMsg.contains("user already registered") || lowerMsg.contains("user_already_exists")) {
            friendlyMessage = "Este correo electrónico ya está registrado.";
        } else if (lowerMsg.contains("password should be")) {
            friendlyMessage = "La contraseña es muy débil. Debe tener al menos 6 caracteres.";
        }

        Map<String, String> response = new HashMap<>();
        response.put("message", friendlyMessage);
        
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, String>> handleResponseStatusException(ResponseStatusException ex) {
        Map<String, String> response = new HashMap<>();
        response.put("message", ex.getReason() != null ? ex.getReason() : ex.getMessage());
        return ResponseEntity.status(ex.getStatusCode()).body(response);
    }

    @ExceptionHandler(WebExchangeBindException.class)
    public ResponseEntity<Map<String, String>> handleWebExchangeBindException(WebExchangeBindException ex) {
        log.error("Validation error caught: {}", ex.getMessage());
        Map<String, String> response = new HashMap<>();
        String firstErrorMessage = ex.getBindingResult().getFieldErrors().stream()
                .map(err -> err.getDefaultMessage())
                .findFirst()
                .orElse("Datos de formulario inválidos");
        
        response.put("message", firstErrorMessage);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, String>> handleGeneralException(Exception ex) {
        log.error("Unhandled exception caught: ", ex);
        Map<String, String> response = new HashMap<>();
        response.put("message", ex.getMessage() != null ? ex.getMessage() : "Ocurrió un error interno en el servidor.");
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
}
