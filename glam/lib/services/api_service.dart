import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http_parser/http_parser.dart';
import '../models/models.dart';
import 'api_config.dart';

class ApiService {
  // Helper to parse response body or throw
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body;
    Map<String, dynamic> data = {};
    if (body.isNotEmpty) {
      try {
        data = jsonDecode(body);
      } catch (_) {
        // Fallback if not JSON
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      final msg = data['message'] ?? 'Error de conexión con el servidor (${response.statusCode})';
      throw Exception(msg);
    }
  }

  // Authentication - Login
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.authLogin),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final data = _handleResponse(response);
    return {
      'token': data['token'] as String,
      'profile': User.fromJson(data['profile'] as Map<String, dynamic>),
    };
  }

  // Authentication - Register
  static Future<void> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.authRegister),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.toLowerCase().trim(),
        'email': email.trim(),
        'password': password,
        'fullName': fullName.trim(),
      }),
    );

    _handleResponse(response);
  }

  // Session Validation
  static Future<User> fetchProfile(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.authMe),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  // Get Feed
  static Future<List<FeedItem>> fetchFeed(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.publicationsFeed),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => FeedItem.fromJson(item)).toList();
    } else {
      throw Exception('No se pudo cargar el Feed Global');
    }
  }

  // Toggle Like (POST for liking, DELETE for unliking)
  static Future<void> toggleLike(String token, int pubId, bool makeLike) async {
    final url = Uri.parse(ApiConfig.publicationLike(pubId));
    final headers = {
      'Authorization': 'Bearer $token',
    };

    final response = makeLike 
        ? await http.post(url, headers: headers) 
        : await http.delete(url, headers: headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo procesar la reacción de Like');
    }
  }

  // Get Comments
  static Future<List<CommentItem>> fetchComments(String token, int pubId, {int page = 0, int size = 10}) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.publicationComments(pubId)}?page=$page&size=$size'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => CommentItem.fromJson(item)).toList();
    } else {
      throw Exception('Error al cargar comentarios');
    }
  }

  // Add Comment
  static Future<void> addComment(String token, int pubId, String content) async {
    final response = await http.post(
      Uri.parse(ApiConfig.publicationComments(pubId)),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo guardar el comentario');
    }
  }

  // Get Filters List
  static Future<List<FilterInfo>> fetchFilters() async {
    final response = await http.get(Uri.parse(ApiConfig.filters));
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => FilterInfo.fromJson(item)).toList();
    } else {
      throw Exception('Error de red al obtener los filtros');
    }
  }

  // Apply PyCUDA Filter (Multipart request)
  static Future<Map<String, dynamic>> applyFilter({
    required String token,
    required List<int> fileBytes,
    required String filename,
    required String filterType,
    required String kernelSize,
  }) async {
    final uri = Uri.parse(ApiConfig.applyFilter);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['filter_type'] = filterType;
    request.fields['kernel_size'] = kernelSize;

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = _handleResponse(response);
    // returns structure like: { metrics: {...}, history: { id, originalImageUrl, processedImageUrl, ... } }
    return data;
  }

  // Fetch dynamic previews for all filters
  static Future<Map<String, dynamic>> fetchPreviews({
    required String token,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final uri = Uri.parse(ApiConfig.generatePreviews);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = _handleResponse(response);
    return data['previews'] as Map<String, dynamic>;
  }

  // Publish Processed (Filter applied already)
  static Future<void> publishProcessed({
    required String token,
    required String caption,
    required String originalUrl,
    required String processedUrl,
    required String filterApplied,
  }) async {
    final response = await http.post(
      Uri.parse(ApiConfig.publicationsProcessed),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'caption': caption,
        'imageUrl': originalUrl,
        'processedImageUrl': processedUrl,
        'filterApplied': filterApplied,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo subir la publicación filtrada');
    }
  }

  // Publish Original (Without filter applied, standard upload)
  static Future<void> publishOriginal({
    required String token,
    required String caption,
    required List<int> fileBytes,
    required String filename,
  }) async {
    final uri = Uri.parse(ApiConfig.publications);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['caption'] = caption;

    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: filename,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('No se pudo subir la publicación original');
    }
  }

  // Retrieve metrics for a given URL
  static Future<GpuMetrics> fetchMetricsByUrl(String token, String url) async {
    final response = await http.get(
      Uri.parse(ApiConfig.metricsByUrl(url)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return GpuMetrics.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('No logged GPU metrics found');
    }
  }

  // Update Profile (Multipart PUT request)
  static Future<User> updateProfile({
    required String token,
    String? username,
    String? fullName,
    List<int>? avatarBytes,
    String? avatarFilename,
  }) async {
    final uri = Uri.parse(ApiConfig.authProfile);
    final request = http.MultipartRequest('PUT', uri);

    request.headers['Authorization'] = 'Bearer $token';
    if (username != null && username.trim().isNotEmpty) {
      request.fields['username'] = username.trim().toLowerCase();
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      request.fields['fullName'] = fullName.trim();
    }

    if (avatarBytes != null && avatarFilename != null) {
      final multipartFile = http.MultipartFile.fromBytes(
        'avatar',
        avatarBytes,
        filename: avatarFilename,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    final data = _handleResponse(response);
    return User.fromJson(data);
  }

  // Fetch Publications of a Specific User
  static Future<List<FeedItem>> fetchUserPublications(String token, String userId) async {
    final response = await http.get(
      Uri.parse(ApiConfig.userPublications(userId)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((json) => FeedItem.fromJson(json)).toList();
    } else {
      throw Exception('Error al cargar publicaciones del usuario (${response.statusCode})');
    }
  }

  // Delete Publication
  static Future<void> deletePublication(String token, int pubId) async {
    final response = await http.delete(
      Uri.parse(ApiConfig.deletePublication(pubId)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Safe fallback if body cannot be parsed or is empty
      String msg = 'No se pudo eliminar la publicación';
      if (response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          msg = data['message'] ?? msg;
        } catch (_) {}
      }
      throw Exception(msg);
    }
  }

  // Helper to dynamically transform Supabase public storage URLs into optimized resizing URLs
  static String getOptimizedImageUrl(String url, {int width = 600}) {
    return url;
  }
}
