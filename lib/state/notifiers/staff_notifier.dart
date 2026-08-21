import 'package:flutter/foundation.dart';
import 'package:emar_kafe/models/staff_member.dart';
import 'package:emar_kafe/services/api_service.dart';

class StaffNotifier extends ChangeNotifier {
  final ApiService api;
  List<StaffMember> staffList = [];
  bool isLoading = false;
  String? error;

  StaffNotifier(this.api);

  Future<void> fetchStaff({String? branchId}) async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final data = await api.getStaff(branchId: branchId);
      staffList = data
          .map((e) => StaffMember.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      error = e.toString();
      debugPrint('Staff fetch error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createStaff({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? branchId,
  }) async {
    try {
      await api.createStaff(
        email: email,
        password: password,
        fullName: fullName,
        role: role,
        branchId: branchId,
      );
      await fetchStaff(branchId: branchId);
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteStaff(String staffId, {String? branchId}) async {
    try {
      await api.deleteStaff(staffId);
      staffList.removeWhere((s) => s.id == staffId);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }
}
