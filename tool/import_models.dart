import 'dart:io';

import 'package:loquiris/core/result.dart';
import 'package:path/path.dart' as path;

import 'model_import/model_importer.dart';

const _usage = 'Usage: dart run tool/import_models.dart';

/// Runs the deterministic offline model import command.
///
/// Inputs are always read from `models/manifests/`, `models/licenses/`, and
/// the ignored `models/local/` tree beneath [projectRoot]. Verified assets are
/// atomically published beneath `build/generated/model_assets/`.
Future<int> runModelImportCommand(
  List<String> arguments, {
  Directory? projectRoot,
  void Function(String line)? writeOutput,
  void Function(String line)? writeError,
}) async {
  final output = writeOutput ?? (line) => stdout.writeln(line);
  final error = writeError ?? (line) => stderr.writeln(line);
  if (arguments.isNotEmpty) {
    error(_usage);
    return 64;
  }

  final root = projectRoot ?? Directory.current;
  final result = await importModels(
    ModelImportRequest(
      projectRoot: root,
      manifestDirectory: Directory(
        path.join(root.path, 'models', 'manifests'),
      ),
      artifactDirectory: Directory(path.join(root.path, 'models', 'local')),
      outputDirectory: Directory(
        path.join(root.path, 'build', 'generated', 'model_assets'),
      ),
    ),
  );
  return switch (result) {
    Ok(:final value) => _reportSuccess(value, output),
    Err(:final failure) => _reportFailure(failure, error),
  };
}

int _reportSuccess(
  ModelImportSummary summary,
  void Function(String line) output,
) {
  final noun = summary.modelIds.length == 1 ? 'model' : 'models';
  output(
    'Imported ${summary.modelIds.length} $noun '
    '(${summary.totalBytes} bytes).',
  );
  return 0;
}

int _reportFailure(
  ModelImportFailure failure,
  void Function(String line) error,
) {
  final model = failure.modelId == null ? '' : ' (${failure.modelId})';
  error('Model import failed: ${failure.code}$model');
  return 1;
}

Future<void> main(List<String> arguments) async {
  exitCode = await runModelImportCommand(arguments);
}
