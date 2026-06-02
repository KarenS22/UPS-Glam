import 'package:flutter/material.dart';
import '../models/models.dart';

class TelemetryOverlay extends StatelessWidget {
  final GpuMetrics metrics;
  final String filterId;
  final bool isCompact;

  const TelemetryOverlay({
    super.key,
    required this.metrics,
    required this.filterId,
    this.isCompact = false,
  });

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 Bytes';
    const k = 1024;
    const List<String> sizes = ['Bytes', 'KB', 'MB', 'GB'];
    
    double val = bytes.toDouble();
    int sizeIdx = 0;
    while (val >= k && sizeIdx < sizes.length - 1) {
      val /= k;
      sizeIdx++;
    }
    return '${val.toStringAsFixed(2)} ${sizes[sizeIdx]}';
  }

  String _formatThreads(int threads) {
    return threads.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    final String imageSize = metrics.imageSize;
    final String blockDim = metrics.blockDim;
    final String gridDim = metrics.gridDim;
    final int totalThreads = metrics.totalThreads;
    final double executionTime = metrics.executionTimeMs;
    final int vramBytes = metrics.memoryUsedBytes;

    final bool isCudaSimulated = executionTime > 15.0;
    final Color accentColor = Colors.white;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 12.0 : 20.0),
      decoration: BoxDecoration(
        color: const Color(0xFF14396A), // Flat solid blue background
        border: Border.all(
          color: Colors.white, // Solid white border
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Telemetry Title & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: isCompact ? 16 : 20,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Detalles de Procesamiento',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: isCompact ? 13 : 15,
                      color: accentColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: Colors.white38,
                    width: 1,
                  ),
                ),
                child: Text(
                  isCudaSimulated ? 'MODO COMPATIBLE (CPU)' : 'GPU NATIVA',
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          if (!isCompact) ...[
            const SizedBox(height: 8),
            const Text(
              'Estadísticas del procesamiento paralelo',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white70,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, height: 1),
          ],
          
          const SizedBox(height: 8),

          // 1. Tamaño de la imagen
          _buildMetricRow(
            icon: Icons.aspect_ratio,
            iconColor: Colors.white,
            label: 'Tamaño de Imagen',
            value: '$imageSize px',
            valueColor: Colors.white,
          ),

          // 2. Dimensión de bloque de kernel
          _buildMetricRow(
            icon: Icons.grid_3x3,
            iconColor: Colors.white,
            label: 'Dimensión de Bloque',
            value: blockDim,
            valueColor: Colors.white,
          ),

          // 3. Dimensión de grid
          _buildMetricRow(
            icon: Icons.grid_on,
            iconColor: Colors.white,
            label: 'Dimensión de Grid',
            value: gridDim,
            valueColor: Colors.white,
          ),

          // 4. Cantidad total de hilos
          _buildMetricRow(
            icon: Icons.waves,
            iconColor: Colors.white,
            label: 'Hilos Lanzados en GPU',
            value: _formatThreads(totalThreads),
            valueColor: Colors.white,
          ),

          // 5. Tiempo de ejecución
          _buildMetricGaugeRow(
            icon: Icons.timer,
            iconColor: Colors.white,
            label: 'Tiempo de Ejecución',
            value: '${executionTime.toStringAsFixed(3)} ms',
            ratio: (executionTime / 100.0).clamp(0.0, 1.0),
            gaugeColor: Colors.white,
          ),

          // 6. Memoria gráfica usada
          _buildMetricGaugeRow(
            icon: Icons.storage,
            iconColor: Colors.white,
            label: 'Uso de Memoria Gráfica',
            value: _formatBytes(vramBytes),
            ratio: (vramBytes / 8388608.0).clamp(0.0, 1.0),
            gaugeColor: Colors.white,
            valueColor: Colors.white,
          ),
        ],
      ),
    );
  }

  // Helper for simple text rows
  Widget _buildMetricRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // Helper for rows with linear progress bar indicators
  Widget _buildMetricGaugeRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required double ratio,
    required Color gaugeColor,
    Color valueColor = Colors.white,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: iconColor),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Container(
              width: double.infinity,
              height: 4,
              color: Colors.white.withValues(alpha: 0.1),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: ratio,
                    heightFactor: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: gaugeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
