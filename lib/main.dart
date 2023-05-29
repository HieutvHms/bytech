// ignore_for_file: public_member_api_docs, lines_longer_than_80_chars
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:reintechnik/new_screen/home/home_screen.dart';

import 'providers/app_provider.dart';

void main() {
  runApp(
    /// Providers are above [MyApp] instead of inside it, so that tests
    /// can use [MyApp] while mocking the providers
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reintechnik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Helvetica',
      ),
      home: const NewHomeScreen2(),
    );
  }
}
