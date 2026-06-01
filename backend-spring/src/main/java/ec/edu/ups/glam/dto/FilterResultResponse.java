package ec.edu.ups.glam.dto;

import ec.edu.ups.glam.model.GpuMetric;
import ec.edu.ups.glam.model.ProcessingHistory;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class FilterResultResponse {
    private ProcessingHistory history;
    private GpuMetric metrics;
}
