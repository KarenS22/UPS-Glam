import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../models/models.dart';
import '../widgets/telemetry_overlay.dart';

class FilterStudioScreen extends StatefulWidget {
  final String token;
  final User currentUser;
  final VoidCallback onPublishSuccess;

  const FilterStudioScreen({
    super.key,
    required this.token,
    required this.currentUser,
    required this.onPublishSuccess,
  });

  @override
  State<FilterStudioScreen> createState() => _FilterStudioScreenState();
}

class _FilterStudioScreenState extends State<FilterStudioScreen> {
  // Local file state
  List<int>? _fileBytes;
  String? _filename;
  String? _previewPath;
  final TextEditingController _captionController = TextEditingController();

  // Filters from backend / fallbacks
  List<FilterInfo> _filters = [];
  String _selectedFilter = 'none';
  String _selectedKernelSize = '9x9';

  // Processing state
  bool _processing = false;
  String _processingStep = '';
  Map<String, dynamic>? _filteredResult; // { metrics: ..., history: ... }
  
  // Client-side cache for processed results of the currently selected image
  final Map<String, Map<String, dynamic>> _processedCache = {};

  // Publishing state
  bool _publishing = false;
  String _error = '';

  // Previews state
  Map<String, dynamic>? _previews;
  bool _loadingPreviews = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _loadPreviews() async {
    if (_fileBytes == null) return;
    setState(() {
      _loadingPreviews = true;
      _previews = null;
    });
    try {
      final previewsMap = await ApiService.fetchPreviews(
        token: widget.token,
        fileBytes: _fileBytes!,
        filename: _filename ?? 'image.jpg',
      );
      setState(() {
        _previews = previewsMap;
      });
    } catch (e) {
      debugPrint("Error loading fast previews: $e");
    } finally {
      setState(() {
        _loadingPreviews = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchFilters();
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _fetchFilters() async {
    try {
      final list = await ApiService.fetchFilters();
      setState(() {
        _filters = list;
      });
    } catch (_) {
      // Seed standard fallback list in case backend is offline
      setState(() {
        _filters = [
          FilterInfo(id: 'blur', name: 'Filtro de Blur', description: 'Suaviza la imagen mediante promedio de vecindad paralela.'),
          FilterInfo(id: 'sharpen', name: 'Filtro Sharpen', description: 'Enfoca detalles finos combinando la imagen con un mapa difuso.'),
          FilterInfo(id: 'sobel', name: 'Filtro Sobel', description: 'Detecta los contornos horizontales y verticales en tiempo real.'),
          FilterInfo(id: 'cartooning', name: 'Filtro de Cartooning', description: 'Transforma la imagen en una caricatura posterizada con bordes marcados.'),
          FilterInfo(id: 'tricolor', name: 'Filtro Tricolor', description: 'Sustituye la paleta de colores por la terna estética #F5BE1A, #123672 y #FFFFFF.'),
          FilterInfo(id: 'tricolor_inverted', name: 'Filtro Tricolor Invertido', description: 'Invierte los colores y luego los reemplaza con amarillo #F5BE1A, azul #123672 y blanco #FFFFFF.'),
          FilterInfo(id: 'recuerdo_historico', name: 'Recuerdo Histórico', description: 'Desenfoque fuerte y tinte duotono nostálgico con colores institucionales.'),
        ];
      });
    }
  }

  Future<void> _handlePickImage(ImageSource source) async {
    try {
      setState(() {
        _error = '';
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _fileBytes = bytes;
          _filename = pickedFile.name;
          _previewPath = pickedFile.path;
          
          // Reset previous results
          _filteredResult = null;
          _selectedFilter = 'none';
          _processedCache.clear();
        });
        _loadPreviews();
      }
    } catch (err) {
      setState(() {
        _error = 'Error al seleccionar la imagen: ${err.toString()}';
      });
    }
  }

  Future<void> _handleApplyFilter() async {
    if (_fileBytes == null || _selectedFilter == 'none') return;
    
    final String cacheKey = '${_selectedFilter}_$_selectedKernelSize';
    if (_processedCache.containsKey(cacheKey)) {
      setState(() {
        _filteredResult = _processedCache[cacheKey];
        _error = '';
      });
      return;
    }
    
    if (_processing) return;

    setState(() {
      _error = '';
      _processing = true;
    });

    // Dramatic PyCUDA compiler loading steps (identical to React lines 127-134)
    final steps = [
      'Espera un momento mientras realizamos el procesamiento...',
      'Preparando todo para obtener el mejor resultado...',
      'Analizando la imagen y ajustando los parámetros...',
      'Aplicando los cambios solicitados...',
      'Ya casi terminamos, gracias por tu paciencia...'
      'Optimizando los últimos detalles...',
      'Estamos haciendo lo mejor posible...',
      'La solicitud está por terminar...',
      'Empacando el resultado final...',
      '¡Listo! Solo falta un instante más...'
    ];

    for (int i = 0; i < steps.length; i++) {
      if (!mounted || !_processing) break;
      setState(() {
        _processingStep = steps[i];
      });
      // Delay slightly for premium dynamic loading effect
      await Future.delayed(Duration(milliseconds: i == 1 ? 700 : 350));
    }

    try {
      final data = await ApiService.applyFilter(
        token: widget.token,
        fileBytes: _fileBytes!,
        filename: _filename ?? 'image.jpg',
        filterType: _selectedFilter,
        kernelSize: _selectedKernelSize,
      );

      setState(() {
        _filteredResult = data;
        _processedCache[cacheKey] = data;
      });
    } catch (err) {
      setState(() {
        _error = 'Error al procesar la imagen: El backend o el microservicio CUDA de GPU no está disponible.';
      });
    } finally {
      setState(() {
        _processing = false;
        _processingStep = '';
      });
    }
  }

  Future<void> _handlePublish() async {
    if (_fileBytes == null) return;

    setState(() {
      _error = '';
      _publishing = true;
    });

    try {
      if (_filteredResult != null && _selectedFilter != 'none') {
        // High fidelity link publishing of pre-processed URLs
        final history = _filteredResult!['history'] as Map<String, dynamic>;
        
        await ApiService.publishProcessed(
          token: widget.token,
          caption: _captionController.text.trim(),
          originalUrl: history['originalImageUrl'] ?? history['original_image_url'] ?? '',
          processedUrl: history['processedImageUrl'] ?? history['processed_image_url'] ?? '',
          filterApplied: _selectedFilter,
        );
      } else {
        // Standard non-filtered multipart upload
        await ApiService.publishOriginal(
          token: widget.token,
          caption: _captionController.text.trim(),
          fileBytes: _fileBytes!,
          filename: _filename ?? 'image.jpg',
        );
      }

      // Clear state and notify parent success to return to feed
      setState(() {
        _fileBytes = null;
        _previewPath = null;
        _filteredResult = null;
        _selectedFilter = 'none';
        _captionController.clear();
      });

      widget.onPublishSuccess();
    } catch (err) {
      setState(() {
        _error = err.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _publishing = false;
      });
    }
  }

  // Simulated visual thumbnail filters in Flutter to match CSS filter preview buttons
  Widget _buildFilterThumbnail(String filterId, String localPath) {
    if (_previews != null && _previews![filterId] != null && _previews![filterId].isNotEmpty) {
      return Image.memory(
        base64Decode(_previews![filterId]),
        fit: BoxFit.cover,
      );
    }

    Widget image = Image.file(
      File(localPath),
      fit: BoxFit.cover,
    );

    // Apply color filter matrix matching CSS styles
    switch (filterId) {
      case 'blur':
        // Soft focus representation
        image = ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.85), BlendMode.modulate),
          child: image,
        );
        break;
      case 'sharpen':
        // High contrast matrix
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.2, 0, 0, 0, -10,
            0, 1.2, 0, 0, -10,
            0, 0, 1.2, 0, -10,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
      case 'sobel':
        // Edge detection representation (invert grayscale)
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -0.33, -0.33, -0.33, 0, 255,
            -0.33, -0.33, -0.33, 0, 255,
            -0.33, -0.33, -0.33, 0, 255,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
      case 'cartooning':
        // High saturated representation
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            1.5, -0.2, -0.2, 0, 0,
            -0.2, 1.5, -0.2, 0, 0,
            -0.2, -0.2, 1.5, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
      case 'tricolor':
        // Yellow, blue and white palette tint
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.5, 0.4, 0.1, 0, 20,
            0.1, 0.3, 0.6, 0, 10,
            0.1, 0.1, 0.2, 0, 50,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
      case 'tricolor_inverted':
        // Inverted representation
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            -0.5, -0.4, -0.1, 0, 235,
            -0.1, -0.3, -0.6, 0, 245,
            -0.1, -0.1, -0.2, 0, 205,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
      case 'stripe_overlay':
        // 1/6 border: outer blue (3/24) and inner white (1/24)
        image = Stack(
          children: [
            Positioned.fill(child: image),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF123672), width: 6),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        );
        break;
      case 'stripe_overlay_horizontal':
        // Grabado del escudo representation: Blue borders/edges on yellow background
        image = Container(
          color: const Color(0xFFF5BE1A),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix([
              -0.33, -0.33, -0.33, 0, 18,
              -0.33, -0.33, -0.33, 0, 54,
              -0.33, -0.33, -0.33, 0, 114,
              0, 0, 0, 1, 0,
            ]),
            child: image,
          ),
        );
        break;
      case 'recuerdo_historico':
        // Strong blur + institutional duotone nostalgic gradient
        image = ColorFiltered(
          colorFilter: const ColorFilter.matrix([
            0.4, 0.4, 0.2, 0, 40,
            0.2, 0.3, 0.4, 0, 20,
            0.1, 0.1, 0.3, 0, 60,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        );
        break;
    }

    if (_loadingPreviews) {
      return Stack(
        children: [
          Positioned.fill(child: image),
          Container(
            color: Colors.black38,
            child: const Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return image;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // // Title Header
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       const Text(
        //         'Laboratorio gráfico',
        //         style: TextStyle(
        //           fontSize: 20,
        //           fontWeight: FontWeight.w800,
        //           color: Colors.white,
        //         ),
        //       ),
        //       const SizedBox(height: 4),
        //       Text(
        //         'Edita tus imágenes con los filtros preestablecidos, míra el resultado y publícalas <3',
        //         style: TextStyle(
        //           fontSize: 12,
        //           color: Colors.grey[400],
        //           height: 1.3,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        // const SizedBox(height: 12),

        // Error message banner
        if (_error.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error,
                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Split Content Area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Upload box OR Preview canvas card
                if (_previewPath == null)
                  _buildUploadBox()
                else
                  _buildPreviewCanvasCard(),

                const SizedBox(height: 24),

                // 2. Right Side: Filters, Telemetry, and Share Form
                if (_previewPath != null) ...[
                  _buildFiltersSelectPanel(),
                  const SizedBox(height: 20),
                  
                  // Returned GPU Telemetry
                  if (_filteredResult != null && _selectedFilter != 'none') ...[
                    TelemetryOverlay(
                      metrics: GpuMetrics.fromJson(_filteredResult!['metrics'] as Map<String, dynamic>),
                      filterId: _selectedFilter,
                    ),
                    const SizedBox(height: 20),
                  ],

                  _buildShareFormPanel(),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Pick Image Dashboard
  Widget _buildUploadBox() {
    return InkWell(
      onTap: () {
        // Show selection bottom sheet
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF14396A),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            side: BorderSide(color: Colors.white, width: 2.0), // Flat white border
          ),
          builder: (context) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.white),
                    title: const Text('Tomar Foto con Cámara', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _handlePickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.image, color: Colors.white),
                    title: const Text('Seleccionar desde la Galería', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      _handlePickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF14396A), // Flat solid blue
          border: Border.all(
            color: Colors.white, // Solid white border
            width: 2,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white38),
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                size: 32,
                color: Colors.white, // Bicolor flat white
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Seleccionar Imagen',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCanvasCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14396A), // Flat solid blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5), // Solid flat white border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Canvas Frame Stack
          AspectRatio(
            aspectRatio: 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                   // Rendering processed URL from Supabase if filtered, otherwise fast base64 preview or localPicked File path
                  Positioned.fill(
                    child: _filteredResult != null
                        ? Image.network(
                            ApiService.getOptimizedImageUrl((_filteredResult!['history'] as Map<String, dynamic>)['processedImageUrl'] ?? ''),
                            fit: BoxFit.cover,
                            cacheWidth: 600,
                            errorBuilder: (context, _, __) => Image.file(File(_previewPath!), fit: BoxFit.cover),
                          )
                        : (_selectedFilter != 'none' && _previews != null && _previews![_selectedFilter] != null && _previews![_selectedFilter].isNotEmpty)
                            ? Image.memory(
                                base64Decode(_previews![_selectedFilter]),
                                fit: BoxFit.cover,
                              )
                            : Image.file(
                                File(_previewPath!),
                                fit: BoxFit.cover,
                              ),
                  ),

                  // Fast preview status overlay badge
                  if (_filteredResult == null && _selectedFilter != 'none')
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_loadingPreviews) ...[
                              const SizedBox(
                                width: 10,
                                height: 10,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              _loadingPreviews
                                  ? 'Cargando previsualización...'
                                  : 'Previsualización instantánea',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // CUDA dramatic compiling steps loading overlay
                  if (_processing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.9),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.memory, size: 44, color: Colors.white),
                            const SizedBox(height: 16),
                            const Text(
                              'PROCESANDO',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Colors.white, // Bicolor white
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _processingStep,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _fileBytes = null;
                    _previewPath = null;
                    _filteredResult = null;
                    _selectedFilter = 'none';
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Cambiar Imagen', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              
              if (_filteredResult != null)
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF06B6D4), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Filtro listo!',
                      style: TextStyle(
                        color: const Color(0xFF06B6D4),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  double _getKernelSliderValue() {
    switch (_selectedKernelSize) {
      case '3x3':
        return 0.0;
      case '128x128':
        return 2.0;
      case '9x9':
      default:
        return 1.0;
    }
  }

  String _getKernelSizeFromSliderValue(double value) {
    if (value < 0.5) {
      return '3x3';
    } else if (value < 1.5) {
      return '9x9';
    } else {
      return '128x128';
    }
  }

  String _getKernelSliderLabel(double value) {
    if (value < 0.5) {
      return 'Poco';
    } else if (value < 1.5) {
      return 'Medio';
    } else {
      return 'Mucho';
    }
  }

  Widget _buildFiltersSelectPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14396A), // Flat solid blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5), // Solid white border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona un filtro de imagen',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Filters selector list
          SizedBox(
            height: 94,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length + 1,
              itemBuilder: (context, idx) {
                final bool isNone = idx == 0;
                final filter = isNone ? null : _filters[idx - 1];
                final String fId = isNone ? 'none' : filter!.id;
                final String fName = isNone ? 'Original' : filter!.name;
                final bool isSelected = _selectedFilter == fId;

                return InkWell(
                  onTap: () {
                    final String cacheKey = '${fId}_$_selectedKernelSize';
                    setState(() {
                      _selectedFilter = fId;
                      if (_processedCache.containsKey(cacheKey)) {
                        _filteredResult = _processedCache[cacheKey];
                      } else {
                        _filteredResult = null;
                      }
                    });
                    if (fId != 'none' && !_processedCache.containsKey(cacheKey)) {
                      _handleApplyFilter();
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.15) // Bicolor select
                          : Colors.white.withValues(alpha: 0.03),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white // Solid white border
                            : Colors.white24,
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: _buildFilterThumbnail(fId, _previewPath!),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Text(
                            fName,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          if (_selectedFilter != 'none') ...[
            const SizedBox(height: 16),
            
            // Premium Kernel Slider Selector Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.01),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Intensidad del filtro',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),

                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                      overlayColor: Colors.white.withOpacity(0.2),
                      valueIndicatorColor: const Color(0xFF14396A),
                      valueIndicatorTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: Slider(
                      value: _getKernelSliderValue(),
                      min: 0.0,
                      max: 2.0,
                      divisions: 2,
                      label: _getKernelSliderLabel(_getKernelSliderValue()),
                      onChanged: _processing
                          ? null
                          : (val) {
                              final String newKernel = _getKernelSizeFromSliderValue(val);
                              final String cacheKey = '${_selectedFilter}_$newKernel';
                              setState(() {
                                _selectedKernelSize = newKernel;
                                if (_processedCache.containsKey(cacheKey)) {
                                  _filteredResult = _processedCache[cacheKey];
                                } else {
                                  _filteredResult = null;
                                }
                              });
                            },
                      onChangeEnd: _processing
                          ? null
                          : (val) {
                              final String newKernel = _getKernelSizeFromSliderValue(val);
                              final String cacheKey = '${_selectedFilter}_$newKernel';
                              if (!_processedCache.containsKey(cacheKey)) {
                                _handleApplyFilter();
                              }
                            },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Poco', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Medio', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                        Text('Mucho', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShareFormPanel() {
    final bool hasFilter = _filteredResult != null && _selectedFilter != 'none';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14396A), // Flat solid blue background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 1.5), // Solid white border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasFilter ? '2. Detalla tu Publicación' : '1. Detalla tu Publicación',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Caption Text Area
          TextField(
            controller: _captionController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Escribe un pie de foto para tu obra reactiva...',
              hintStyle: const TextStyle(color: Colors.white54, fontSize: 12.5),
              filled: true,
              fillColor: const Color(0xFF14396A), // Flat solid blue
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Share Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _publishing ? null : _handlePublish,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // Flat White accent
                foregroundColor: const Color(0xFF14396A), // Flat Blue contrast
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0, // Flat design
              ),
              icon: _publishing 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, 
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14396A)),
                      ),
                    )
                  : const Icon(Icons.share_outlined, size: 16),
              label: Text(
                _publishing ? 'Publicando...' : 'Compartir en el Feed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
