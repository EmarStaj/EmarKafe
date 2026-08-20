class Branch {
  final Map<String, String>? workingHours;
  final String id;
  final String name;
  final String? address;
  final bool isActive;

  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.workingHours,
  });

  factory Branch.fromDb(Map<String, dynamic> row) {
    Map<String, String>? hours;
    if (row['working_hours'] != null) {
      if (row['working_hours'] is Map) {
        hours = (row['working_hours'] as Map).map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    }
    return Branch(
      id: row['id'] as String,
      name: row['name'] as String,
      address: row['address'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      workingHours: hours,
    );
  }
}
