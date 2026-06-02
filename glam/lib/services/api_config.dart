import 'package:flutter/foundation.dart';

class ApiConfig {
  // Configurable base URL. By default, it dynamically checks platform and environment.
  static String? _customBaseUrl;

  static String get baseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.isNotEmpty) {
      return _customBaseUrl!;
    }
    
    if (kIsWeb) {
      return '/api';
    }

    return 'https://03vcqqp7-8080.brs.devtunnels.ms/api';
  }

  static set customBaseUrl(String url) {
    if (url.endsWith('/')) {
      _customBaseUrl = url.substring(0, url.length - 1);
    } else {
      _customBaseUrl = url;
    }
  }

  // Endpoints
  static String get authLogin => '$baseUrl/auth/login';
  static String get authRegister => '$baseUrl/auth/register';
  static String get authMe => '$baseUrl/auth/me';
  static String get authProfile => '$baseUrl/auth/profile';
  
  static String get publicationsFeed => '$baseUrl/publications/feed';
  static String get publications => '$baseUrl/publications';
  static String get publicationsProcessed => '$baseUrl/publications/processed';
  static String userPublications(String userId) => '$baseUrl/publications/user/$userId';
  static String deletePublication(int pubId) => '$baseUrl/publications/$pubId';
  
  static String publicationLike(int pubId) => '$baseUrl/publications/$pubId/like';
  static String publicationComments(int pubId) => '$baseUrl/publications/$pubId/comments';
  
  static String get filters => '$baseUrl/processing/filters';
  static String get applyFilter => '$baseUrl/processing/apply-filter';
  static String get generatePreviews => '$baseUrl/processing/previews';
  static String metricsByUrl(String url) => '$baseUrl/processing/metrics/by-url?url=${Uri.encodeComponent(url)}';
}
