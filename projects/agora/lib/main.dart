import 'package:flutter/material.dart';

void main() {
  runApp(const Bootstrap());
}

class Bootstrap extends StatelessWidget {
  const Bootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Agora'))),
    );
  }
}
