package ec.edu.ups.glam.service;

import ec.edu.ups.glam.dto.FilterResultResponse;
import ec.edu.ups.glam.model.GpuMetric;
import ec.edu.ups.glam.model.ProcessingHistory;
import ec.edu.ups.glam.repository.GpuMetricRepository;
import ec.edu.ups.glam.repository.ProcessingHistoryRepository;
import com.fasterxml.jackson.databind.JsonNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.MultipartBodyBuilder;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.BodyInserters;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Base64;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class GpuProcessingService {

    private final WebClient webClient;
    private final SupabaseStorageService storageService;
    private final ProcessingHistoryRepository historyRepository;
    private final GpuMetricRepository metricRepository;

    @Value("${cuda.service.url}")
    private String cudaServiceUrl;

    /**
     * Applies a GPU filter to an image by sending it to the PyCUDA microservice,
     * uploads original and processed images to Supabase storage, and logs historical database records.
     * 
     * @param imageBytes The raw original image bytes.
     * @param filterType The filter type (blur, sharpen, sobel, cartooning, tricolor, tricolor_inverted, recuerdo_historico).
     * @param kernelSize The chosen kernel size (9x9, 128x128, 301x301).
     * @param userId     The UUID of the authenticated user requesting the filter.
     * @return Mono of FilterResultResponse containing both database entities.
     */
    public Mono<FilterResultResponse> applyFilter(byte[] imageBytes, String filterType, String kernelSize, UUID userId) {
        String processUrl = cudaServiceUrl + "/process";
        log.info("Sending image filter request to PyCUDA service: {} for filter: {} with kernel: {}", processUrl, filterType, kernelSize);

        // Build multipart body
        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        builder.part("file", new ByteArrayResource(imageBytes) {
            @Override
            public String getFilename() {
                return "original_image.jpg";
            }
        }, MediaType.IMAGE_JPEG);
        builder.part("filter_type", filterType);
        builder.part("kernel_size", kernelSize);

        // 1. Post to PyCUDA Service
        return webClient.post()
                .uri(processUrl)
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(BodyInserters.fromMultipartData(builder.build()))
                .retrieve()
                .bodyToMono(JsonNode.class)
                .flatMap(node -> {
                    // Extract response values
                    String imgBase64 = node.get("image_base64").asText();
                    JsonNode metricsNode = node.get("metrics");
                    
                    byte[] processedBytes = Base64.getDecoder().decode(imgBase64);

                    String origName = "original/" + storageService.generateUniqueFileName(".jpg");
                    String procName = "processed/" + storageService.generateUniqueFileName(".jpg");

                    // 2. Upload Original and Processed images in parallel (using Mono.zip)
                    Mono<String> origUpload = storageService.uploadImage(imageBytes, origName, "image/jpeg");
                    Mono<String> procUpload = storageService.uploadImage(processedBytes, procName, "image/jpeg");

                    return Mono.zip(origUpload, procUpload)
                            .flatMap(tuple -> {
                                String originalUrl = tuple.getT1();
                                String processedUrl = tuple.getT2();

                                // 3. Save to Processing History
                                ProcessingHistory history = ProcessingHistory.builder()
                                        .userId(userId)
                                        .originalImageUrl(originalUrl)
                                        .processedImageUrl(processedUrl)
                                        .filterId(filterType)
                                        .build();

                                return historyRepository.save(history)
                                        .flatMap(savedHistory -> {
                                            // 4. Save to GPU Metrics
                                            GpuMetric metric = GpuMetric.builder()
                                                    .processingId(savedHistory.getId())
                                                    .imageSize(metricsNode.get("image_size").asText())
                                                    .blockDim(metricsNode.get("block_dim").asText())
                                                    .gridDim(metricsNode.get("grid_dim").asText())
                                                    .totalThreads(metricsNode.get("total_threads").asLong())
                                                    .executionTimeMs(metricsNode.get("execution_time_ms").asDouble())
                                                    .memoryUsedBytes(metricsNode.get("memory_used_bytes").asLong())
                                                    .build();

                                            return metricRepository.save(metric)
                                                    .map(savedMetric -> FilterResultResponse.builder()
                                                            .history(savedHistory)
                                                            .metrics(savedMetric)
                                                            .build()
                                                    );
                                        });
                            });
                })
                .doOnError(err -> log.error("Failed to complete GPU image processing pipeline: {}", err.getMessage()));
    }

    /**
     * Calls PyCUDA to generate 254x254 preview thumbnails for all filters.
     */
    public Mono<JsonNode> generatePreviews(byte[] imageBytes) {
        String previewUrl = cudaServiceUrl + "/preview";
        log.info("Requesting all image previews from PyCUDA service: {}", previewUrl);

        MultipartBodyBuilder builder = new MultipartBodyBuilder();
        builder.part("file", new ByteArrayResource(imageBytes) {
            @Override
            public String getFilename() {
                return "preview_image.jpg";
            }
        }, MediaType.IMAGE_JPEG);

        return webClient.post()
                .uri(previewUrl)
                .contentType(MediaType.MULTIPART_FORM_DATA)
                .body(BodyInserters.fromMultipartData(builder.build()))
                .retrieve()
                .bodyToMono(JsonNode.class)
                .doOnError(err -> log.error("Failed to generate PyCUDA image previews: {}", err.getMessage()));
    }
}
