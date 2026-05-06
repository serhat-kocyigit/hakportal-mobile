import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/user_panel_screen.dart';
import '../screens/lawyer_panel_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/ai_chat_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/user_panel',
        builder: (context, state) => const UserPanelScreen(),
      ),
      GoRoute(
        path: '/lawyer_panel',
        builder: (context, state) => const LawyerPanelScreen(),
      ),
      GoRoute(
        path: '/admin_panel',
        builder: (context, state) => const AdminPanelScreen(),
      ),
      GoRoute(
        path: '/ai_chat',
        builder: (context, state) => const AIChatScreen(),
      ),
      GoRoute(
        path: '/chat/:caseId',
        builder: (context, state) {
          final caseId = state.pathParameters['caseId']!;
          return ChatScreen(caseId: caseId);
        },
      ),
    ],
  );
}
