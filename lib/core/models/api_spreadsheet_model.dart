int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class ApiSpreadsheet {
  final int id;
  final String title;
  final String description;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final String creatorName;
  final String creatorEmail;
  final int totalLeads;
  final List<ApiColumn> columns;
  final List<ApiRow> rows;
  final List<ApiAssignedUser> assignedUsers;
  final List<ApiEditHistory> editHistory;

  ApiSpreadsheet({
    required this.id,
    required this.title,
    this.description = '',
    this.createdBy = 0,
    this.createdAt = '',
    this.updatedAt = '',
    required this.creatorName,
    this.creatorEmail = '',
    this.totalLeads = 0,
    required this.columns,
    required this.rows,
    this.assignedUsers = const [],
    this.editHistory = const [],
  });

  factory ApiSpreadsheet.fromJson(Map<String, dynamic> json) {
    List<ApiColumn> parsedCols = (json['columns'] as List? ?? [])
        .map((c) => ApiColumn.fromJson(c))
        .toList();

    List<ApiRow> parsedRows = (json['rows'] as List? ?? [])
        .map((r) => ApiRow.fromJson(r))
        .toList();

    List<ApiAssignedUser> parsedAssigned = (json['assigned_users'] as List? ?? [])
        .map((u) => ApiAssignedUser.fromJson(u))
        .toList();

    List<ApiEditHistory> parsedHistory = (json['edit_history'] as List? ?? [])
        .map((h) => ApiEditHistory.fromJson(h))
        .toList();

    return ApiSpreadsheet(
      id: _parseInt(json['id']),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      createdBy: _parseInt(json['created_by']),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      creatorName: json['creator_name'] ?? json['created_by_name'] ?? '',
      creatorEmail: json['creator_email']?.toString() ?? '',
      totalLeads: _parseInt(json['total_leads'] ?? json['total_rows'] ?? parsedRows.length),
      columns: parsedCols,
      rows: parsedRows,
      assignedUsers: parsedAssigned,
      editHistory: parsedHistory,
    );
  }
}

class ApiEditHistory {
  final int id;
  final int sheetId;
  final int rowId;
  final int rowIndex;
  final int userId;
  final String userName;
  final String userRole;
  final String columnName;
  final String oldValue;
  final String newValue;
  final String createdAt;

  ApiEditHistory({
    required this.id,
    required this.sheetId,
    required this.rowId,
    this.rowIndex = 0,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.columnName,
    required this.oldValue,
    required this.newValue,
    required this.createdAt,
  });

  factory ApiEditHistory.fromJson(Map<String, dynamic> json) {
    return ApiEditHistory(
      id: _parseInt(json['id']),
      sheetId: _parseInt(json['sheet_id']),
      rowId: _parseInt(json['row_id']),
      rowIndex: _parseInt(json['row_index']),
      userId: _parseInt(json['user_id']),
      userName: json['user_name']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      columnName: json['column_name']?.toString() ?? '',
      oldValue: json['old_value']?.toString() ?? '',
      newValue: json['new_value']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ApiAssignedUser {
  final int id;
  final int sheetId;
  final int userId;
  final String role;
  final String name;
  final String email;
  final int groupId;
  final String groupName;
  final int? assignedBy;
  final String? assignedAt;

  ApiAssignedUser({
    required this.id,
    required this.sheetId,
    required this.userId,
    this.role = 'edit',
    required this.name,
    this.email = '',
    required this.groupId,
    required this.groupName,
    this.assignedBy,
    this.assignedAt,
  });

  factory ApiAssignedUser.fromJson(Map<String, dynamic> json) {
    return ApiAssignedUser(
      id: _parseInt(json['id']),
      sheetId: _parseInt(json['sheet_id']),
      userId: _parseInt(json['user_id']),
      role: json['role']?.toString() ?? 'edit',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      groupId: _parseInt(json['group_id']),
      groupName: json['group_name']?.toString() ?? '',
      assignedBy: json['assigned_by'] != null ? _parseInt(json['assigned_by']) : null,
      assignedAt: json['assigned_at']?.toString(),
    );
  }

  bool get isExecutive => groupId == 4 || groupId == 5 || groupName.toLowerCase().contains('exec') || groupName.toLowerCase().contains('staff');
  bool get isAccounts => groupId == 2 || groupName.toLowerCase().contains('account');
  bool get isManager => groupId == 6 || groupId == 1 || groupName.toLowerCase().contains('manager');
}

class ApiColumn {
  final int id;
  final int sheetId;
  final String columnKey;
  final String columnName;
  final String columnType; // 'text', 'number', 'dropdown'
  final String userType; // 'common', 'executive', 'accounts'
  final List<String> options;
  final int sortOrder;
  final String createdAt;

  ApiColumn({
    required this.id,
    this.sheetId = 0,
    required this.columnKey,
    required this.columnName,
    required this.columnType,
    this.userType = 'common',
    this.options = const [],
    this.sortOrder = 0,
    this.createdAt = '',
  });

  factory ApiColumn.fromJson(Map<String, dynamic> json) {
    final rawKey = json['column_key']?.toString() ?? '';
    final rawName = json['column_name']?.toString() ?? '';
    final idVal = _parseInt(json['id']);

    final effectiveKey = rawKey.isNotEmpty
        ? rawKey
        : (rawName.isNotEmpty ? rawName : 'col_$idVal');

    List<String> parsedOptions = [];
    if (json['options'] != null) {
      if (json['options'] is List) {
        parsedOptions = (json['options'] as List).map((e) => e.toString()).toList();
      }
    }

    return ApiColumn(
      id: idVal,
      sheetId: _parseInt(json['sheet_id']),
      columnKey: effectiveKey,
      columnName: rawName.isNotEmpty ? rawName : effectiveKey,
      columnType: json['column_type']?.toString() ?? 'text',
      userType: (json['user_type']?.toString() ?? 'common').trim().toLowerCase(),
      options: parsedOptions,
      sortOrder: _parseInt(json['sort_order']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  bool get isCommon => userType == 'common' || (userType != 'executive' && userType != 'accounts');
  bool get isExecutive => userType == 'executive';
  bool get isAccounts => userType == 'accounts';
}

class ApiRow {
  int id;
  final int sheetId;
  int rowIndex;
  String status;
  final int? createdBy;
  final String? createdByName;
  final int? assignedTo;
  final String? assignedToName;
  final String? createdAt;
  final String? updatedAt;
  final Map<String, dynamic> data;

  ApiRow({
    required this.id,
    required this.sheetId,
    this.rowIndex = 0,
    required this.status,
    this.createdBy,
    this.createdByName,
    this.assignedTo,
    this.assignedToName,
    this.createdAt,
    this.updatedAt,
    required this.data,
  });

  factory ApiRow.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> parsedData = {};
    if (json['data'] is Map) {
      parsedData = Map<String, dynamic>.from(json['data']);
    }

    return ApiRow(
      id: _parseInt(json['id']),
      sheetId: _parseInt(json['sheet_id']),
      rowIndex: _parseInt(json['row_index']),
      status: json['status']?.toString() ?? 'new',
      createdBy: json['created_by'] != null ? _parseInt(json['created_by']) : null,
      createdByName: json['created_by_name']?.toString(),
      assignedTo: json['assigned_to'] != null ? _parseInt(json['assigned_to']) : null,
      assignedToName: json['assigned_to_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
      data: parsedData,
    );
  }

  /// Safe accessor for cell value by columnKey, columnName, or col_id
  String getValue(ApiColumn col) {
    // 1. Direct match on columnKey
    if (data.containsKey(col.columnKey)) {
      final val = data[col.columnKey]?.toString() ?? '';
      if (val.isNotEmpty) return val;
    }
    // 2. Direct match on columnName
    if (data.containsKey(col.columnName)) {
      final val = data[col.columnName]?.toString() ?? '';
      if (val.isNotEmpty) return val;
    }
    // 3. Case-insensitive / trimmed match on columnName
    final cleanColName = col.columnName.trim().toLowerCase();
    for (var entry in data.entries) {
      if (entry.key.trim().toLowerCase() == cleanColName) {
        final val = entry.value?.toString() ?? '';
        if (val.isNotEmpty) return val;
      }
    }
    // 4. Alt key match: col_{id}
    final altKey = 'col_${col.id}';
    if (data.containsKey(altKey)) {
      final val = data[altKey]?.toString() ?? '';
      if (val.isNotEmpty) return val;
    }
    // 5. If key exists with empty string, return it
    if (data.containsKey(col.columnKey)) {
      return data[col.columnKey]?.toString() ?? '';
    }
    if (data.containsKey(col.columnName)) {
      return data[col.columnName]?.toString() ?? '';
    }
    return '';
  }

  /// Helper to get student/lead name
  String get leadName {
    for (var key in ['Name', 'name', 'Lead Name', 'lead_name', 'Student Name', 'student_name']) {
      if (data.containsKey(key) && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }
    // Check col_2_... (standard Name column_key)
    for (var entry in data.entries) {
      if (entry.key.startsWith('col_2_') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    for (var entry in data.entries) {
      if (entry.key.toLowerCase().contains('name') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return 'Lead #$id';
  }

  /// Helper to get phone number
  String get phoneNumber {
    for (var key in ['Number', 'number', 'Phone', 'phone', 'Phone Number', 'mobile']) {
      if (data.containsKey(key) && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }
    // Check col_1_... (standard Number column_key)
    for (var entry in data.entries) {
      if (entry.key.startsWith('col_1_') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    for (var entry in data.entries) {
      if (entry.key.toLowerCase().contains('number') || entry.key.toLowerCase().contains('phone')) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  /// Helper to get country
  String get country {
    for (var key in ['Country', 'country']) {
      if (data.containsKey(key) && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }
    // Check col_3_... (standard Country column_key)
    for (var entry in data.entries) {
      if (entry.key.startsWith('col_3_') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  /// Helper to get working amount
  String get workingAmount {
    for (var key in ['Working Amount', 'working_amount', 'Amount', 'amount']) {
      if (data.containsKey(key) && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }
    // Check col_4_... (standard Working Amount column_key)
    for (var entry in data.entries) {
      if (entry.key.startsWith('col_4_') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  /// Helper to get agency name
  String get agencyName {
    for (var key in ['Agency Name', 'agency_name', 'Agency', 'agency']) {
      if (data.containsKey(key) && data[key].toString().trim().isNotEmpty) {
        return data[key].toString().trim();
      }
    }
    // Check col_5_... (standard Agency Name column_key)
    for (var entry in data.entries) {
      if (entry.key.startsWith('col_5_') && entry.value.toString().trim().isNotEmpty) {
        return entry.value.toString().trim();
      }
    }
    return '';
  }

  void setValue(ApiColumn col, String value) {
    data[col.columnKey] = value;
    data[col.columnName] = value;
  }
}
