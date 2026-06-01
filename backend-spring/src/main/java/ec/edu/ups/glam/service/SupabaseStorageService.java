package ec.edu.ups.glam.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Slf4j
@Service
public class SupabaseStorageService {

    private final WebClient webClient;

    @Value("${supabase.url}")
    private String supabaseUrl;

    @Value("${supabase.anon-key}")
    private String supabaseAnonKey;

    @Value("${supabase.service-role-key}")
    private String supabaseServiceRoleKey;

    @Value("${supabase.bucket-name:instagram}")
    private String bucketName;

    public SupabaseStorageService(WebClient webClient) {
        this.webClient = webClient;
    }

    /**
     * Uploads binary image bytes directly to Supabase Storage bucket and returns the public URL.
     * 
     * @param imageBytes The raw bytes of the image.
     * @param fileName   The destination file path/name within the bucket.
     * @param contentType The MIME type (e.g., image/jpeg or image/png).
     * @return Mono containing the public URL of the uploaded image.
     */
    public Mono<String> uploadImage(byte[] imageBytes, String fileName, String contentType) {
        String uploadUrl = String.format("%s/storage/v1/object/%s/%s", supabaseUrl, bucketName, fileName);
        log.info("Uploading image to Supabase Storage: {} (size: {} bytes)", uploadUrl, imageBytes.length);

        return webClient.post()
                .uri(uploadUrl)
                .header("apikey", supabaseAnonKey)
                // Use service role key to bypass storage RLS policies in the backend
                .header("Authorization", "Bearer " + supabaseServiceRoleKey)
                .contentType(MediaType.parseMediaType(contentType))
                .bodyValue(imageBytes)
                .retrieve()
                .toBodilessEntity()
                .map(response -> {
                    // Resolve the public URL directly
                    String publicUrl = String.format("%s/storage/v1/object/public/%s/%s", supabaseUrl, bucketName, fileName);
                    log.info("Image uploaded successfully. Public URL: {}", publicUrl);
                    return publicUrl;
                })
                .doOnError(err -> log.error("Failed to upload image to Supabase Storage: {}", err.getMessage()));
     }
 
     /**
      * Deletes an image from Supabase Storage by its public URL.
      * 
      * @param imageUrl The public URL of the image.
      * @return Mono<Void>
      */
     public Mono<Void> deleteImage(String imageUrl) {
         if (imageUrl == null || imageUrl.isEmpty()) {
             return Mono.empty();
         }
         
         log.info("Request to delete image from Supabase Storage: {}", imageUrl);
         
         // Extract the file path from the public URL.
         // Public URL format: [supabaseUrl]/storage/v1/object/public/[bucketName]/[fileName]
         String prefix = String.format("/storage/v1/object/public/%s/", bucketName);
         int index = imageUrl.indexOf(prefix);
         if (index == -1) {
             log.warn("Could not extract file path from URL: {}", imageUrl);
             return Mono.empty();
         }
         
         String fileName = imageUrl.substring(index + prefix.length());
         String deleteUrl = String.format("%s/storage/v1/object/%s/%s", supabaseUrl, bucketName, fileName);
         log.info("Deleting object from Supabase Storage: {}", deleteUrl);
         
         return webClient.delete()
                 .uri(deleteUrl)
                 .header("apikey", supabaseAnonKey)
                 .header("Authorization", "Bearer " + supabaseServiceRoleKey)
                 .retrieve()
                 .toBodilessEntity()
                 .then()
                 .doOnError(err -> log.error("Failed to delete image from Supabase Storage: {}", err.getMessage()))
                 .onErrorResume(err -> Mono.empty()); // Gracefully ignore errors to not fail the transaction
     }
 
     /**
      * Generates a unique file name using UUIDs to prevent naming collisions in storage.
      */
     public String generateUniqueFileName(String extension) {
         return UUID.randomUUID().toString() + (extension.startsWith(".") ? extension : "." + extension);
     }
 }
