package com.instagram.backend.dto;

import com.instagram.backend.model.GpuMetric;
import com.instagram.backend.model.ProcessingHistory;
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
