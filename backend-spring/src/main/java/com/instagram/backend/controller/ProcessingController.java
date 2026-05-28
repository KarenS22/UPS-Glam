package com.instagram.backend.controller;

import com.instagram.backend.dto.FilterResultResponse;
import com.instagram.backend.model.FilterInfo;
import com.instagram.backend.model.GpuMetric;
import com.instagram.backend.model.ProcessingHistory;
import com.instagram.backend.repository.FilterInfoRepository;
import com.instagram.backend.repository.GpuMetricRepository;
import com.instagram.backend.repository.ProcessingHistoryRepository;
import com.instagram.backend.service.GpuProcessingService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.buffer.DataBufferUtils;
import org.springframework.http.MediaType;
import org.springframework.http.codec.multipart.FilePart;
import org.springframework.security.core.context.ReactiveSecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/processing")
@RequiredArgsConstructor
public class ProcessingController {

    private final GpuProcessingService gpuProcessingService;
    private final FilterInfoRepository filterInfoRepository;
    private final ProcessingHistoryRepository historyRepository;
    private final GpuMetricRepository metricRepository;

    @PostMapping(value = "/apply-filter", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Mono<FilterResultResponse> applyFilter(
            @RequestPart("file") FilePart filePart,
            @RequestPart("filter_type") String filterType,
            @RequestPart(value = "kernel_size", required = false) String kernelSize) {
        
        log.info("Request received to apply filter '{}' (kernel: '{}') to uploaded image", filterType, kernelSize);
        String finalKernelSize = (kernelSize != null) ? kernelSize : "9x9";

        return ReactiveSecurityContextHolder.getContext()
                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                .flatMap(userId -> 
                        filePartToBytes(filePart)
                                .flatMap(bytes -> gpuProcessingService.applyFilter(bytes, filterType, finalKernelSize, userId))
                );
    }

    @PostMapping(value = "/previews", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public Mono<com.fasterxml.jackson.databind.JsonNode> generatePreviews(
            @RequestPart("file") FilePart filePart) {
        log.info("Request received to generate fast image previews");
        return filePartToBytes(filePart)
                .flatMap(gpuProcessingService::generatePreviews);
    }

    @GetMapping("/filters")
    public Flux<FilterInfo> getAvailableFilters() {
        log.info("Fetching available filters from database");
        return filterInfoRepository.findAll();
    }

    @GetMapping("/history")
    public Flux<ProcessingHistory> getProcessingHistory() {
        log.info("Fetching image processing history for currently authenticated user");
        
        return ReactiveSecurityContextHolder.getContext()
                .map(ctx -> (UUID) ctx.getAuthentication().getPrincipal())
                .flatMapMany(historyRepository::findAllByUserIdOrderByCreatedAtDesc);
    }

    @GetMapping("/metrics/{processingId}")
    public Mono<GpuMetric> getGpuMetrics(@PathVariable Integer processingId) {
        log.info("Fetching GPU metrics for processing transaction ID: {}", processingId);
        return metricRepository.findByProcessingId(processingId);
    }

    @GetMapping("/metrics/by-url")
    public Mono<GpuMetric> getGpuMetricsByUrl(@RequestParam("url") String url) {
        log.info("Fetching GPU metrics for processed image URL: {}", url);
        return historyRepository.findFirstByProcessedImageUrl(url)
                .flatMap(history -> metricRepository.findByProcessingId(history.getId()))
                .switchIfEmpty(Mono.error(new IllegalArgumentException("No GPU metrics found for the specified image URL")));
    }

    /**
     * Helper to read reactive FilePart content and assemble a linear byte array.
     */
    private Mono<byte[]> filePartToBytes(FilePart filePart) {
        return filePart.content()
                .map(dataBuffer -> {
                    byte[] bytes = new byte[dataBuffer.readableByteCount()];
                    dataBuffer.read(bytes);
                    DataBufferUtils.release(dataBuffer); // Release buffer to avoid memory leaks
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
}
