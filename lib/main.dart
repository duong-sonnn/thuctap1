import 'package:firebase_core/firebase_core.dart';
import 'package:image_generator_app/home_page.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'sign_in_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Generator App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SignInPage(),
        // '/home': (context) => const HomeScreen(),
         '/home': (context) => const HomePage(),
      },
    );
  }
}
