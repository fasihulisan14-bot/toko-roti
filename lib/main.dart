import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        Provider(create: (_) => ApiService()),
      ],
      child: MaterialApp(
        title: 'Bakery System',
        theme: ThemeData(
          primarySwatch: Colors.brown,
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        home: AuthWrapper(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isInitialLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuthStatus();
  }

  void _checkInitialAuthStatus() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();

    setState(() {
      _isInitialLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Debug print
        print('🔄 AuthWrapper rebuild:');
        print('   _isInitialLoading: $_isInitialLoading');
        print('   isAuthenticated: ${authProvider.isAuthenticated}');
        print('   Token: ${authProvider.token != null ? "ADA" : "NULL"}');

        // Initial loading
        if (_isInitialLoading) {
          print('   ⏳ Menampilkan LOADING SCREEN');
          return _buildLoadingScreen();
        }

        // Auth state changed? Handle navigation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleAuthChange(authProvider, context);
        });

        // Tampilkan screen berdasarkan auth status
        if (authProvider.isAuthenticated) {
          print('   🏠 Menampilkan HOMEPAGE');
          return HomePage();
        } else {
          print('   🔐 Menampilkan LOGIN PAGE');
          return LoginPage();
        }
      },
    );
  }

  void _handleAuthChange(AuthProvider authProvider, BuildContext context) {
    // Get current route name (jika ada)
    final currentRoute = ModalRoute.of(context)?.settings.name;
    print('   🧭 Current route: $currentRoute');
    print('   🎯 isAuthenticated: ${authProvider.isAuthenticated}');

    // Jika tidak authenticated tapi masih di HomePage, redirect ke login
    if (!authProvider.isAuthenticated) {
      print(
          '   🔄 Auth changed: NOT authenticated, checking if need redirect...');

      // Cek apakah sedang di halaman selain login
      if (currentRoute != 'login' &&
          ModalRoute.of(context)?.isCurrent == true) {
        print('   🚀 Redirecting to LoginPage...');

        // Gunakan pushAndRemoveUntil dengan MaterialPageRoute
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => LoginPage(),
            settings: RouteSettings(name: 'login'),
          ),
          (Route<dynamic> route) => false, // Hapus semua routes sebelumnya
        );
      }
    }

    // Jika authenticated tapi di LoginPage, redirect ke home
    if (authProvider.isAuthenticated && currentRoute == 'login') {
      print('   🚀 Redirecting to HomePage...');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => HomePage()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cake, size: 60, color: Colors.brown),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Memeriksa autentikasi...'),
          ],
        ),
      ),
    );
  }
}
