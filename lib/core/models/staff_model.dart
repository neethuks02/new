class StaffModel {
  final int id;
  final String name;
  final String email;
  final int groupId;
  final String groupName;
  final int status;
  final String? createdAt;

  StaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.groupId,
    required this.groupName,
    required this.status,
    this.createdAt,
  });

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      groupId: json['group_id'] is int ? json['group_id'] : int.parse(json['group_id'].toString()),
      groupName: json['group_name'] ?? '',
      status: json['status'] is int ? json['status'] : int.parse(json['status'].toString()),
      createdAt: json['created_at'],
    );
  }
}
