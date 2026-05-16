class PickedFile {
  const PickedFile({
    required this.name,
    required this.path,
    this.isValid = true,
    this.errorMessage,
  });

  final String name;
  final String path;
  final bool isValid;
  final String? errorMessage;
}
