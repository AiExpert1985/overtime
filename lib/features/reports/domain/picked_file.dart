class PickedFile {
  const PickedFile({
    required this.name,
    required this.path,
    this.isValid = false,
    this.isValidating = false,
    this.errorMessage,
  });

  final String name;
  final String path;
  final bool isValid;
  final bool isValidating;
  final String? errorMessage;
}
