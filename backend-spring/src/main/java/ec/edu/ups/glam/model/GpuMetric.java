package ec.edu.ups.glam.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.Id;
import org.springframework.data.relational.core.mapping.Column;
import org.springframework.data.relational.core.mapping.Table;

import java.time.Instant;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@Table("gpu_metrics")
public class GpuMetric {

    @Id
    private Integer id;

    @Column("processing_id")
    private Integer processingId;

    @Column("image_size")
    private String imageSize;

    @Column("block_dim")
    private String blockDim;

    @Column("grid_dim")
    private String gridDim;

    @Column("total_threads")
    private Long totalThreads;

    @Column("execution_time_ms")
    private Double executionTimeMs;

    @Column("memory_used_bytes")
    private Long memoryUsedBytes;

    @Column("is_gpu")
    private Boolean isGpu;

    @Column("created_at")
    @Builder.Default
    private Instant createdAt = Instant.now();
}
