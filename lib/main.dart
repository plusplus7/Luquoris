import 'package:flutter/widgets.dart';
import 'package:loquiris/app.dart';
import 'package:loquiris/bootstrap/bootstrap.dart';
import 'package:loquiris/bootstrap/diagnostic_log.dart';
import 'package:loquiris/bootstrap/error_handlers.dart';

/// Installs crash containment, builds local dependencies, and starts Loquiris.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final diagnosticLog = await openApplicationDiagnosticLog();
  installErrorHandlers(diagnosticLog);

  final dependencies = await bootstrap(diagnosticLogSink: diagnosticLog);
  runApp(
    buildLoquirisRoot(
      dependencies: dependencies,
      child: const LoquirisApp(),
    ),
  );
}
