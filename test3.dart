void main() {
  String version = "AV01-NEW_HW-004.1";
  
  // Test 1: effectiveVersion
  String effectiveVersion = version.replaceAll(RegExp(r'[-_]\d+(\.\d+)*$'), '');
  print('Effective: $effectiveVersion');
  
  // Test 2: extractVersionNumber
  final clean = version.replaceAll('.bin', '').trim();
  final parts = clean.split(RegExp(r'[-_]'));
  final lastPart = parts.last;
  print('Last Part: $lastPart');
  
  // Try parsing double instead of int
  double versionNum = double.tryParse(lastPart) ?? 0.0;
  print('Parsed Number: $versionNum');
}
