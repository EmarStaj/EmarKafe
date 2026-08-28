import 'package:emar_kafe/models/branch.dart';
import 'package:flutter/foundation.dart';
import 'package:emar_kafe/services/api_service.dart';
import 'package:emar_kafe/data/catalog.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

enum UserRole { customer, barista, manager, branchManager, admin }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.customer:
        return 'Müşteri';
      case UserRole.barista:
        return 'Barista';
      case UserRole.manager:
        return 'Yönetici';
      case UserRole.branchManager:
        return 'Şube Yöneticisi';
      case UserRole.admin:
        return 'Sistem Yöneticisi';
    }
  }

  String get backendValue {
    switch (this) {
      case UserRole.customer:
        return 'customer';
      case UserRole.barista:
        return 'barista';
      case UserRole.manager:
      case UserRole.branchManager:
        return 'branch_manager';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String? roleStr) {
    if (roleStr == null) return UserRole.customer;
    final normalized =
        roleStr.toLowerCase().replaceAll('_', '').replaceAll('-', '');
    if (normalized == 'branchmanager' || normalized == 'manager') {
      return UserRole.branchManager;
    }
    if (normalized == 'barista') return UserRole.barista;
    if (normalized == 'admin') return UserRole.admin;
    return UserRole.customer;
  }
}

class AuthNotifier extends ChangeNotifier {
  final ApiService api;

  bool loggedIn = false;
  String userId = '';
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

  Future<void> refreshBranches() async {
    try {
      final list = await api.getBranches();
      if (list.isNotEmpty) {
        final bList = list.map((b) => Branch.fromDb(b as Map<String, dynamic>)).toList();
        Catalog.instance.registerBranches(bList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Refresh branches error: $e');
    }
  }

  Future<bool> createBranch({
    required String name,
    String? address,
    String? phoneNumber,
    bool isActive = true,
  }) async {
    try {
      await api.createBranch(
        name: name,
        address: address,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
      await refreshBranches();
      return true;
    } catch (e) {
      debugPrint('Create branch error: $e');
      return false;
    }
  }

  Future<bool> updateBranch(
    String branchId, {
    String? name,
    String? address,
    String? phoneNumber,
    bool? isActive,
  }) async {
    try {
      await api.updateBranch(
        branchId,
        name: name,
        address: address,
        phoneNumber: phoneNumber,
        isActive: isActive,
      );
      await refreshBranches();
      return true;
    } catch (e) {
      debugPrint('Update branch error: $e');
      return false;
    }
  }

  Future<bool> deleteBranch(String branchId) async {
    try {
      await api.deleteBranch(branchId);
      Catalog.instance.removeBranch(branchId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Delete branch error: $e');
      return false;
    }
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

      userId = userObj['id'] ?? '';
      userEmail = userObj['email'] ?? '';

      String fallbackName = metadata?['full_name'] ?? '';

      try {
        final profile = await api.getProfile();
        userName = profile['full_name'] ?? fallbackName;
        role = UserRoleExt.fromString(
          profile['role'] ??
              userObj['role'] ??
              metadata?['role'] ??
              'customer',
        );

        if (profile['birth_date'] != null)
          birthday = DateTime.tryParse(profile['birth_date']);
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
        role: selectedRole.backendValue,
        branchId: branch,
      );

      final session = res['session'] as Map<String, dynamic>?;
      final token =
          res['token'] ?? res['access_token'] ?? session?['access_token'];
      final refreshToken = session?['refresh_token'];

      if (token != null) {
        await api.saveTokens(token, refreshToken: refreshToken);
        try {
          await api.setDefaultBranch(branch);
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

  Future<String?> loginWithCredentials({
    required String email,
    required String password,
  }) async {
    try {
      final res = await api.login(email.trim(), password);
      final session = res['session'] as Map<String, dynamic>?;
      final token =
          res['token'] ?? res['access_token'] ?? session?['access_token'];
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
    userId = '';
    userName = '';
    userEmail = '';
    role = UserRole.customer;
    notifyListeners();
  }

  Future<void> updateEmail(String newEmail) async {
    await api.updateEmail(newEmail.trim());
    userEmail = newEmail.trim();
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    await api.deleteAccount();
    loggedIn = false;
    userId = '';
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
