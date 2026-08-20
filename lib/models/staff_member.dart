class StaffMember {
  final String id;
  final String fullName;
  final String? email;
  final String role;
  final String? branchId;
  final String? branchName;
  final String createdAt;

  const StaffMember({
    required this.id,
    required this.fullName,
    this.email,
    required this.role,
    this.branchId,
    this.branchName,
    required this.createdAt,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? json['name'] as String? ?? 'İsimsiz',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'barista',
      branchId: json['branch_id'] as String?,
      branchName: json['branch_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  String get roleLabel => switch (role) {
        'barista' => 'Barista',
        'branch_manager' => 'Şube Müdürü',
        'admin' => 'Admin',
        _ => role,
      };
}
