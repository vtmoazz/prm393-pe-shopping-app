import 'package:go_router/go_router.dart';

import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'screens/admin_users_screen.dart';
import 'screens/affiliate_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/product_form_screen.dart';
import 'screens/product_list_screen.dart';
import 'screens/register_screen.dart';
import 'screens/revenue_screen.dart';

GoRouter buildRouter(AuthProvider auth, ProductProvider products) {
  const publicRoutes = {'/login', '/register'};
  final editRoute = RegExp(r'^/products/(\d+)/edit$');

  return GoRouter(
    initialLocation: '/products',
    refreshListenable: auth,
    redirect: (context, state) {
      final isPublic = publicRoutes.contains(state.matchedLocation);
      final user = auth.user;
      if (user == null) return isPublic ? null : '/login';
      if (isPublic) return '/products';

      // Each role only reaches its own screens, even by deep link.
      final location = state.matchedLocation;
      final allowed = switch (location) {
        '/products/new' => user.isSeller,
        '/cart' || '/affiliate' => user.isCustomer,
        '/admin/users' => user.isAdmin,
        _ => true,
      };
      if (!allowed) return '/products';
      final edit = editRoute.firstMatch(location);
      if (edit != null) {
        final product = products.findById(int.parse(edit.group(1)!));
        if (product == null || !user.canManage(product)) return '/products';
      }
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
            builder: (_, state) => ProductDetailScreen(
              productId: int.parse(state.pathParameters['id']!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, state) => ProductFormScreen(
                  productId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/cart', builder: (_, _) => const CartScreen()),
      GoRoute(path: '/affiliate', builder: (_, _) => const AffiliateScreen()),
      GoRoute(path: '/revenue', builder: (_, _) => const RevenueScreen()),
      GoRoute(
        path: '/admin/users',
        builder: (_, _) => const AdminUsersScreen(),
      ),
    ],
  );
}
