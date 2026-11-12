import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'screens/cart_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/register_screen.dart';
import 'screens/revenue_screen.dart';

GoRouter buildRouter(AuthProvider auth) {
  const publicRoutes = {'/login', '/register'};

  return GoRouter(
    initialLocation: '/products',
    refreshListenable: auth,
    redirect: (context, state) {
      final isPublic = publicRoutes.contains(state.matchedLocation);
      if (!auth.isLoggedIn && !isPublic) return '/login';
      if (auth.isLoggedIn && isPublic) return '/products';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: '/products',
        builder: (_, _) => const ProductListScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ProductFormScreen()),
          GoRoute(
            path: ':id',
            builder: (_, state) =>
                ProductDetailScreen(productId: int.parse(state.pathParameters['id']!)),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) =>
                    ProductFormScreen(productId: int.parse(state.pathParameters['id']!)),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/revenue', builder: (_, _) => const RevenueScreen()),
    ],
  );
}
