import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';
import 'models/models.dart';
import 'screens/login_register_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/filter_studio_screen.dart';
import 'screens/edit_profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPS GLAM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF14396A),
        primaryColor: const Color(0xFFFFFFFF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFFFFF),
          secondary: Color(0xFFFFFFFF),
          surface: Color(0xFF14396A),
          error: Color(0xFFEF4444),
        ),
        fontFamily: 'Outfit',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFE2E8F0)),
        ),
        useMaterial3: true,
      ),
      home: const MainOrchestrator(),
    );
  }
}

class MainOrchestrator extends StatefulWidget {
  const MainOrchestrator({super.key});

  @override
  State<MainOrchestrator> createState() => _MainOrchestratorState();
}

class _MainOrchestratorState extends State<MainOrchestrator> {
  String? _token;
  User? _currentUser;
  String _activeTab = 'feed'; // 'feed' | 'studio'
  bool _authChecked = false;

  @override
  void initState() {
    super.initState();
    _checkAuthSession();
  }

  Future<void> _checkAuthSession() async {
    try {
      final token = await StorageService.getToken();
      if (token != null && token.isNotEmpty) {
        // Validate session and retrieve fresh user profile from backend
        final profile = await ApiService.fetchProfile(token);

        setState(() {
          _token = token;
          _currentUser = profile;
        });

        // Save fresh profile locally
        await StorageService.saveSession(token, profile.toJson());
      }
    } catch (err) {
      // Token is expired or backend is offline, clear locally
      _handleLogout();
    } finally {
      setState(() {
        _authChecked = true;
      });
    }
  }

  void _handleLoginSuccess(String token, User profile) {
    setState(() {
      _token = token;
      _currentUser = profile;
      _activeTab = 'feed';
    });
  }

  Future<void> _handleLogout() async {
    await StorageService.clearSession();
    setState(() {
      _token = null;
      _currentUser = null;
      _activeTab = 'feed';
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. Sleek session startup loading screen
    if (!_authChecked) {
      return Scaffold(
        backgroundColor: const Color(0xFF14396A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.asset(
                    'assets/logo.jpg',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'CARGANDO UPS GLAM',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Auth Gate: Show login register if no token
    if (_token == null || _currentUser == null) {
      return LoginRegisterScreen(onLoginSuccess: _handleLoginSuccess);
    }

    // 3. Authenticated App Layout Frame
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF14396A), // Flat solid blue background
            border: Border(
              bottom: BorderSide(
                color: Colors.white, // Solid white bottom border
                width: 1.5,
              ),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App Brand Logo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 1.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                            'assets/logo.jpg',
                            width: 24,
                            height: 24,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'UPS GLAM',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Small Studio Label
                      // Container(
                      //   padding: const EdgeInsets.symmetric(
                      //     horizontal: 4,
                      //     vertical: 2,
                      //   ),
                      //   decoration: BoxDecoration(
                      //     borderRadius: BorderRadius.circular(4),
                      //     border: Border.all(color: Colors.white),
                      //   ),
                      //   child: const Text(
                      //     'CUDA',
                      //     style: TextStyle(
                      //       fontSize: 7,
                      //       fontWeight: FontWeight.bold,
                      //       color: Colors.white,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),

                  // Session Profile & LogOut controls
                  Row(
                    children: [
                      // Clickable profile block to edit account
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(
                                token: _token!,
                                currentUser: _currentUser!,
                                onProfileUpdated: (updatedUser) {
                                  setState(() {
                                    _currentUser = updatedUser;
                                  });
                                },
                              ),
                            ),
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            children: [
                              // User circular avatar / letter thumbnail
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  color: const Color(0xFF14396A),
                                ),
                                child: ClipOval(
                                  child:
                                      (_currentUser!.avatarUrl != null &&
                                          _currentUser!.avatarUrl!.isNotEmpty)
                                      ? Image.network(
                                          ApiService.getOptimizedImageUrl(
                                            _currentUser!.avatarUrl!,
                                          ),
                                          fit: BoxFit.cover,
                                          cacheWidth: 100,
                                          errorBuilder: (context, _, __) =>
                                              Center(
                                                child: Text(
                                                  _currentUser!
                                                          .username
                                                          .isNotEmpty
                                                      ? _currentUser!
                                                            .username[0]
                                                            .toUpperCase()
                                                      : 'U',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                        )
                                      : Center(
                                          child: Text(
                                            _currentUser!.username.isNotEmpty
                                                ? _currentUser!.username[0]
                                                      .toUpperCase()
                                                : 'U',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '@${_currentUser!.username}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF3F4F6),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.settings,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Logout action button
                      IconButton(
                        icon: const Icon(Icons.logout, size: 16),
                        color: Colors.grey[500],
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _handleLogout,
                        tooltip: 'Cerrar Sesión',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // Dynamic Page Body Switching
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Navigation Tab Bar (directly underneath the header)
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: _buildNavTabButton(
                      label: 'Posts',
                      icon: Icons.grid_view,
                      isActive: _activeTab == 'feed',
                      activeColor: Colors.white,
                      activeBgColor: Colors.white.withValues(alpha: 0.15),
                      borderColor: Colors.white,
                      onTap: () {
                        setState(() {
                          _activeTab = 'feed';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildNavTabButton(
                      label: 'Studio',
                      icon: Icons.memory,
                      isActive: _activeTab == 'studio',
                      activeColor: Colors.white,
                      activeBgColor: Colors.white.withValues(alpha: 0.15),
                      borderColor: Colors.white,
                      onTap: () {
                        setState(() {
                          _activeTab = 'studio';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            Expanded(
              child: Padding(
                padding: _activeTab == 'feed'
                    ? EdgeInsets.zero
                    : const EdgeInsets.only(top: 8.0),
                child: _activeTab == 'feed'
                    ? FeedScreen(token: _token!, currentUser: _currentUser!)
                    : FilterStudioScreen(
                        token: _token!,
                        currentUser: _currentUser!,
                        onPublishSuccess: () {
                          setState(() {
                            _activeTab = 'feed';
                          });
                        },
                      ),
              ),
            ),

            // // Monospace flat footer
            // Container(
            //   width: double.infinity,
            //   padding: const EdgeInsets.symmetric(vertical: 12.0),
            //   decoration: const BoxDecoration(
            //     border: Border(
            //       top: BorderSide(
            //         color: Colors.white24,
            //       ),
            //     ),
            //   ),
            //   child: const Text(
            //     'UPS GLAM // TECNOLOGÍA EN PARALELO & ARQUITECTURA REACTIVA // 2026',
            //     style: TextStyle(
            //       fontFamily: 'monospace',
            //       fontSize: 8.5,
            //       color: Colors.white54,
            //     ),
            //     textAlign: TextAlign.center,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  // Navigation tab bar buttons builder
  Widget _buildNavTabButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color activeBgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeBgColor : Colors.transparent,
          border: Border.all(
            color: isActive
                ? borderColor
                : Colors.white.withValues(alpha: 0.05),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? activeColor : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isActive ? activeColor : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
