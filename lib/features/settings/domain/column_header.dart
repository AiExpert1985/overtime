class ColumnHeader {
  const ColumnHeader({
    required this.id,
    required this.fileType,
    required this.fieldKey,
    required this.headerValue,
    required this.isDefault,
  });

  final int id;
  final String fileType;
  final String fieldKey;
  final String headerValue;
  final bool isDefault;

  factory ColumnHeader.fromMap(Map<String, dynamic> map) {
    return ColumnHeader(
      id: map['id'] as int,
      fileType: map['file_type'] as String,
      fieldKey: map['field_key'] as String,
      headerValue: map['header_value'] as String,
      isDefault: (map['is_default'] as int) == 1,
    );
  }
}
