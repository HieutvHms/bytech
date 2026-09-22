void main() {
  String version = "AV01-NEW_HW-004";
  String effectiveVersion = version.replaceAll(RegExp(r'[-_]\d+$'), '');
  print(effectiveVersion);
}
