import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/products_page.dart';
import 'pages/add_product_page.dart';
import 'services/supabase_service.dart';
import 'services/product_service.dart';
import 'models/product.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Try to load .env file (for local development and Vercel builds)
  // The .env file will be created from Vercel environment variables during build
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file not found - this should not happen in production
    // If it does, the build script should create it from environment variables
  }
  
  // Get Supabase credentials from .env file
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  
  // Validate credentials before initializing
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Configuration Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Supabase credentials are missing.\nURL: ${supabaseUrl.isEmpty ? "Missing" : "OK"}\nKey: ${supabaseAnonKey.isEmpty ? "Missing" : "OK"}',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ));
    return;
  }
  
  // Initialize Supabase
  try {
    await SupabaseService.initialize(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  } catch (e) {
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Initialization Error',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to initialize Supabase:\n$e',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    return;
  }
  
  // Pre-load products for instant display
  ProductService().preloadProducts();
  
  runApp(const MyApp());
}

// Helper class to listen to auth state changes
class _AuthState extends ChangeNotifier {
  _AuthState() {
    SupabaseService().client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}

final _authState = _AuthState();

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authState,
  redirect: (BuildContext context, GoRouterState state) {
    final supabaseService = SupabaseService();
    final isAuthenticated = supabaseService.isAuthenticated();
    final isLoginRoute = state.matchedLocation == '/login';
    
    // If not authenticated and trying to access protected route, redirect to login
    if (!isAuthenticated && !isLoginRoute) {
      return '/login';
    }
    
    // If authenticated and on login page, redirect to dashboard
    if (isAuthenticated && isLoginRoute) {
      return '/dashboard';
    }
    
    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsPage(),
    ),
    GoRoute(
      path: '/products/add',
      builder: (context, state) {
        final extra = state.extra;
        Product? product;
        if (extra is Map<String, dynamic>?) {
          product = extra?['product'] as Product?;
        } else if (extra is Product) {
          product = extra;
        }
        return AddProductPage(
          product: product,
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'REDWOLF MEDIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDC2626),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      routerConfig: _router,
    );
  }
}
