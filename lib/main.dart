import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tutorias_app/firebase_options.dart';
import 'package:tutorias_app/screens/admin_dashboard_screen.dart';
import 'package:tutorias_app/screens/student_form_screen.dart';
import 'package:tutorias_app/services/local_notifications_service.dart';
import 'package:tutorias_app/services/student_listener_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await LocalNotificationsService.init();

  runApp(const TutoriasApp());
}

class TutoriasApp extends StatelessWidget {
  const TutoriasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tutorias FIM',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade900),
      ),
      home: const PantallaSeleccionRol(),
    );
  }
}

class PantallaSeleccionRol extends StatelessWidget {
  const PantallaSeleccionRol({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de Roles')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
                );
              },
              child: const Text('Entrar como Administrador (Tutorias)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Matricula de prueba. En produccion, esto viene del login real.
                const matriculaPrueba = '12345678';

                // Iniciamos el vigilante invisible de notificaciones para este alumno
                StudentListenerService.iniciarEscucha(matriculaPrueba);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const StudentFormScreen(currentUserId: matriculaPrueba),
                  ),
                );
              },
              child: const Text('Entrar como Estudiante (12345678)'),
            ),
          ],
        ),
      ),
    );
  }
}
