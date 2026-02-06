import '../models/user.dart';

class AuthService {
  Future<AppUser> login({required String email, required String password}) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return const AppUser(
      id: 'u-001',
      name: 'Ayaan Khan',
      username: 'ayaan',
      role: 'Admin',
    );
  }

  Future<AppUser> signup({
    required String name,
    required String username,
    required String email,
    required String password,
    required String role,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return AppUser(id: 'u-002', name: name, username: username, role: role);
  }

  Future<void> logout() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
