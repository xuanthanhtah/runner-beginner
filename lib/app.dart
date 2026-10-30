import 'package:flutter/material.dart';

import 'ui/theme.dart';
import 'ui/workout_screen.dart';

class RunWalkApp extends StatelessWidget {
  const RunWalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Run Walk Timer',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const WorkoutScreen(),
    );
  }
}
