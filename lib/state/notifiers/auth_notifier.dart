import 'package:emar_kafe/models/branch.dart';
import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

enum UserRole { customer, barista, manager, branchManager, admin }
extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.customer: return 'Müşteri';
      case UserRole.barista: return 'Barista';
      case UserRole.manager: return 'Yönetici';
      case UserRole.branchManager: return 'Şube Yöneticisi';
      case UserRole.admin: return 'Sistem Yöneticisi';
    }
  }
}

class AuthNotifier extends ChangeNotifier {
  final ApiService api;
  
  bool loggedIn = false;
  String userName = '';
  String userEmail = '';
  DateTime? birthday;
  UserRole role = UserRole.customer;
  String? selectedBranchId;
  List<Branch> get branches => Catalog.instance.branches;
  
  String get selectedBranchName => getBranchName(selectedBranchId);

  String getBranchName(String? branchId) {
    if (branchId == null || branchId.isEmpty) return 'Şube Seç';
    final branch = branches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => Branch(id: branchId, name: branchId),
    );
    return branch.name;
  }
  
  AuthNotifier(this.api) {
    selectedBranchId = branches.firstOrNull?.id;
    init();
  }

  Future<void> init() async {
    await api.init();
    if (api.token != null) {
      await fetchMe();
    }
  }

  Future<void> fetchMe() async {
    try {
      final res = await api.getMe();
      final userObj = res['user'] as Map<String, dynamic>? ?? res;
      final metadata = userObj['user_metadata'] as Map<String, dynamic>?;

      userEmail = userObj['email'] ?? '';
      
      String fallbackName = metadata?['full_name'] ?? '';
      
      try {
        final profile = await api.getProfile();
        userName = profile['full_name'] ?? fallbackName;
        role = UserRole.values.firstWhere((e) => e.name == (profile['role'] ?? userObj['role'] ?? metadata?['role'] ?? 'customer'), orElse: () => UserRole.customer);
        
        if (profile['birth_date'] != null) birthday = DateTime.tryParse(profile['birth_date']);
        final branchData = profile['branch_id'] ?? profile['branch'];
        if (branchData != null) {
          if (branchData is Map) {
            selectedBranchId = branchData['id'] ?? branchData['branch_id'];
          } else {
            selectedBranchId = branchData.toString();
          }
        }
      } catch (_) {
        userName = fallbackName;
        role = UserRole.customer;
      }

      loggedIn = true;
      OneSignal.login(userEmail);
      final osId = OneSignal.User.pushSubscription.id;
      if (osId != null) {
        api.registerDeviceToken(osId);
      }
      notifyListeners();
    } catch (_) {
      loggedIn = false;
      notifyListeners();
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required DateTime birthDate,
    required UserRole selectedRole,
    required String branch,
  }) async {
    try {
      final res = await api.register(
        email,
        phone,
        password,
        name,
        birthDate.toIso8601String().split('T').first,
        role: selectedRole.name,
        branchId: branch,
      );
      
      final session = res['session'] as Map<String, dynamic>?;
      final token = res['token'] ?? res['access_token'] ?? session?['access_token'];
      final refreshToken = session?['refresh_token'];

      if (token != null) {
        await api.saveTokens(token, refreshToken: refreshToken);
        try {
          await api.setDefaultBranch(branch);
          if (selectedRole != UserRole.customer) {
            await api.updateProfile(role: selectedRole.name);
          }
        } catch (_) {}
        await fetchMe();
        return null;
      } else {
        throw Exception('Kayıt başarılı ama token dönmedi!');
      }
    } catch (e) {
      await api.clearToken();
      loggedIn = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<String?> loginWithCredentials({required String email, required String password}) async {
    try {
      final res = await api.login(email.trim(), password);
      final session = res['session'] as Map<String, dynamic>?;
      final token = res['token'] ?? res['access_token'] ?? session?['access_token'];
      final refreshToken = session?['refresh_token'];
                    
      if (token != null) {
        await api.saveTokens(token, refreshToken: refreshToken);
        await fetchMe();
        return null;
      } else {
        throw Exception('Backend token döndürmedi!');
      }
    } catch (e) {
      await api.clearToken();
      loggedIn = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> logout() async {
    await api.logout();
    loggedIn = false;
    userName = '';
    userEmail = '';
    role = UserRole.customer;
    notifyListeners();
  }

  void selectBranch(String branchId) {
    selectedBranchId = branchId;
    if (loggedIn) {
      api.setDefaultBranch(branchId).catchError((_) {});
    }
    notifyListeners();
  }
}
