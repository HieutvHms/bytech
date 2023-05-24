class Wifi {
  final String name;
  final String? password;

  Wifi({required this.name, this.password});
  Wifi copywith({required String fillPassword}) {
    return Wifi(name: name, password: fillPassword);
  }

  @override
  String toString() {
    return "Name : $name + Pass  : $password";
  }
}
