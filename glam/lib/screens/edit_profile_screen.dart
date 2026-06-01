import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/models.dart';
import '../widgets/glass_panel.dart';

class EditProfileScreen extends StatefulWidget {
  final String token;
  final User currentUser;
  final Function(User) onProfileUpdated;

  const EditProfileScreen({
    super.key,
    required this.token,
    required this.currentUser,
    required this.onProfileUpdated,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _fullNameController;

  // Local avatar file state
  List<int>? _avatarBytes;
  String? _avatarFilename;
  String? _localAvatarPath;

  bool _loading = false;
  String _error = '';
  String _success = '';

  // Publication History state
  List<Publication> _myPublications = [];
  bool _loadingPublications = true;
  String _publicationsError = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.currentUser.username);
    _fullNameController = TextEditingController(text: widget.currentUser.fullName);
    _fetchMyPublications();
  }

  Future<void> _fetchMyPublications() async {
    if (!mounted) return;
    setState(() {
      _loadingPublications = true;
      _publicationsError = '';
    });

    try {
      final list = await ApiService.fetchUserPublications(widget.token, widget.currentUser.id);
      if (mounted) {
        setState(() {
          _myPublications = list.map((item) => item.publication).toList();
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _publicationsError = 'Error al cargar tus publicaciones: ${err.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingPublications = false;
        });
      }
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString).toLocal();
      final months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      return '${date.day} de ${months[date.month - 1]}, ${date.year}';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _handleDeletePublication(Publication pub) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14396A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white, width: 2.0),
        ),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text(
              '¿Eliminar Publicación?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Esta acción eliminará de forma permanente esta publicación. Esta operación no se puede deshacer.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF14396A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      // Show loading HUD
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ),
      );

      try {
        await ApiService.deletePublication(widget.token, pub.id);
        
        if (!mounted) return;
        Navigator.pop(context); // Close HUD

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Publicación eliminada con éxito!'),
            backgroundColor: Colors.cyan,
          ),
        );

        _fetchMyPublications(); // Refresh list
        widget.onProfileUpdated(widget.currentUser); // Propagate reload to parent screen
      } catch (err) {
        if (!mounted) return;
        Navigator.pop(context); // Close HUD
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: ${err.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _handlePickAvatar(ImageSource source) async {
    try {
      setState(() {
        _error = '';
        _success = '';
      });

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 400, // Small and optimized for avatars!
        maxHeight: 400,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
          _avatarFilename = pickedFile.name;
          _localAvatarPath = pickedFile.path;
        });
      }
    } catch (err) {
      setState(() {
        _error = 'Error al seleccionar la imagen de perfil: ${err.toString()}';
      });
    }
  }

  Future<void> _handleUpdateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = '';
      _success = '';
    });

    try {
      final updatedUser = await ApiService.updateProfile(
        token: widget.token,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        avatarBytes: _avatarBytes,
        avatarFilename: _avatarFilename,
      );

      // Persist the updated session locally
      await StorageService.saveSession(widget.token, updatedUser.toJson());

      // Callback to update parent orchestrator state
      widget.onProfileUpdated(updatedUser);

      setState(() {
        _success = '¡Perfil actualizado con éxito!';
        
        // Reset local picked avatar since it is now uploaded
        _avatarBytes = null;
        _avatarFilename = null;
        _localAvatarPath = null;
      });

      if (!mounted) return;

      // Close keyboard
      FocusScope.of(context).unfocus();

      // Return home after a brief delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } catch (err) {
      setState(() {
        _error = err.toString().replaceAll('Exception:', '').trim();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14396A), // Flat solid blue background
      appBar: AppBar(
        backgroundColor: const Color(0xFF14396A),
        title: const Text(
          'Gestionar Cuenta',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Colors.white24, width: 1.5),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Avatar selection and layout
                Center(
                  child: Stack(
                    children: [
                      // Circular Avatar Container
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white, // Flat solid white border
                            width: 2.5,
                          ),
                          color: const Color(0xFF14396A),
                        ),
                        child: ClipOval(
                          child: _localAvatarPath != null
                              ? Image.file(
                                  File(_localAvatarPath!),
                                  fit: BoxFit.cover,
                                )
                              : (widget.currentUser.avatarUrl != null &&
                                      widget.currentUser.avatarUrl!.isNotEmpty)
                                  ? Image.network(
                                      ApiService.getOptimizedImageUrl(widget.currentUser.avatarUrl!),
                                      fit: BoxFit.cover,
                                      cacheWidth: 300,
                                      errorBuilder: (context, _, __) => _buildLetterAvatar(),
                                    )
                                  : _buildLetterAvatar(),
                        ),
                      ),
 
                      // Cam Icon edit action overlay button
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: () => _showPickImageOptions(),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white, // Flat white
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 16,
                              color: Color(0xFF14396A), // Flat blue
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                Text(
                  'Edita tu perfil: cambia tu foto, nombre o apodo.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),

                // Error Banner
                if (_error.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
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
                  const SizedBox(height: 20),
                ],

                // Success Banner
                if (_success.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.cyan.withValues(alpha: 0.25)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.cyanAccent, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _success,
                            style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 2. Input Fields Panel
                GlassPanel(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Información del Perfil',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Username Input Field
                      Text(
                        'Nombre de Usuario (Seudónimo)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _usernameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ej. siryorch',
                          prefixText: '@',
                          prefixStyle: const TextStyle(color: Colors.white70),
                          filled: true,
                          fillColor: const Color(0xFF14396A),
                          contentPadding: const EdgeInsets.all(14),
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre de usuario no puede estar vacío';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Full Name Input Field
                      Text(
                        'Nombre Completo',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400]),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _fullNameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'ej. Jorge Peralta',
                          filled: true,
                          fillColor: const Color(0xFF14396A),
                          contentPadding: const EdgeInsets.all(14),
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
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El nombre completo no puede estar vacío';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // 3. Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _handleUpdateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white, // Flat White accent
                      foregroundColor: const Color(0xFF14396A), // Flat Blue contrast
                      disabledBackgroundColor: Colors.white.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0, // Flat design
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14396A)),
                            ),
                          )
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(
                      _loading ? 'Guardando Cambios...' : 'Guardar y Actualizar',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 24),

                // 4. Publication History Section
                Row(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Historial de tus Publicaciones',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white38),
                      ),
                      child: Text(
                        '${_myPublications.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _loadingPublications
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      )
                    : _publicationsError.isNotEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Text(
                                _publicationsError,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _myPublications.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                                  child: Column(
                                    children: [
                                      Icon(Icons.photo_library_outlined, size: 36, color: Colors.white.withValues(alpha: 0.5)),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Aún no has hecho ninguna publicación',
                                        style: TextStyle(color: Colors.white70, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _myPublications.length,
                                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (context, index) {
                                  final pub = _myPublications[index];
                                  final bool isFiltered = pub.processedImageUrl != null &&
                                                          pub.processedImageUrl!.isNotEmpty &&
                                                          pub.filterApplied != null &&
                                                          pub.filterApplied != 'none';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Post Thumbnail
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: 60,
                                            height: 60,
                                            color: const Color(0xFF14396A),
                                            child: Image.network(
                                              ApiService.getOptimizedImageUrl(
                                                (pub.processedImageUrl != null && pub.processedImageUrl!.isNotEmpty)
                                                    ? pub.processedImageUrl!
                                                    : pub.imageUrl,
                                                width: 200,
                                              ),
                                              fit: BoxFit.cover,
                                              cacheWidth: 120,
                                              errorBuilder: (c, e, s) => const Center(
                                                child: Icon(Icons.broken_image, color: Colors.white60, size: 20),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),

                                        // Metadata & Caption
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    _formatDate(pub.createdAt),
                                                    style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600),
                                                  ),
                                                  if (isFiltered) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      constraints: const BoxConstraints(maxWidth: 100),
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white, // Solid flat white
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        pub.filterApplied!.toUpperCase(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(
                                                          color: Color(0xFF14396A), // Flat blue
                                                          fontSize: 8,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                (pub.caption != null && pub.caption!.isNotEmpty)
                                                    ? pub.caption!
                                                    : 'Sin descripción',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: (pub.caption != null && pub.caption!.isNotEmpty) ? Colors.white70 : Colors.grey[600],
                                                  fontSize: 12.5,
                                                  height: 1.3,
                                                  fontStyle: (pub.caption != null && pub.caption!.isNotEmpty) ? FontStyle.normal : FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),

                                        // Delete Button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => _handleDeletePublication(pub),
                                          tooltip: 'Eliminar Publicación',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLetterAvatar() {
    return Container(
      color: const Color(0xFF14396A), // Flat blue
      child: Center(
        child: Text(
          widget.currentUser.username.isNotEmpty
              ? widget.currentUser.username[0].toUpperCase()
              : 'U',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPickImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14396A), // Flat blue
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
                leading: const Icon(Icons.camera_alt, color: Colors.white), // Flat white
                title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.white), // Flat white
                title: const Text('Elegir de la Galería', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _handlePickAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
