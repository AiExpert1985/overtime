// Three fixed roles. Identity (admin/generate/audit) is fixed in code; only
// each role's username/password is user-editable, by the admin, from the
// Settings screen — see AuthRepository.
enum UserRole {
  admin,
  generate,
  audit;

  String get arabicLabel => switch (this) {
    UserRole.admin => 'المسؤول',
    UserRole.generate => 'مولّد التقارير',
    UserRole.audit => 'المدقق',
  };
}
