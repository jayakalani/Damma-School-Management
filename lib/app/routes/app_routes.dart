import 'package:flutter/material.dart';

class AppRoutes {
  const AppRoutes._();

  static const foundation = '/';

  static final routes = <String, WidgetBuilder>{
    foundation: (_) => const FoundationPage(),
  };
}

class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Damma School Management System'),
            SizedBox(height: 8),
            Text('Application Foundation'),
          ],
        ),
      ),
    );
  }
}