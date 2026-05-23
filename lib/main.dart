import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mylocker/Screens/splash_screen.dart';

import 'firebase_options.dart';

void main() async {
  // 1. Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Initialize Firebase
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );

  // 3. Just start the app at the Splash Screen
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  ));
}
