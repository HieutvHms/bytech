void main() {
  String clean = 'AV01-NEW_HW-004';
  final matches = RegExp(r'\d+').allMatches(clean).toList();
  print(matches.map((m) => m.group(0)).toList());
  print(int.tryParse(matches.last.group(0)!));
}
