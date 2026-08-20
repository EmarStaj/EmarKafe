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
    // Backend returns opening_hours
    final hoursData = row['opening_hours'] ?? row['working_hours'];
    if (hoursData != null && hoursData is Map) {
      hours = (hoursData as Map).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      );
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
