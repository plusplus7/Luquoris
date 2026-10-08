import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'third_party_notices/third_party_notice_generator.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runThirdPartyNoticeCli(
    arguments,
    currentDirectory: Directory.current,
    writeOutput: stdout.writeln,
    writeError: stderr.writeln,
  );
}

/// Runs the offline third-party notice candidate and drift workflow.
Future<int> runThirdPartyNoticeCli(
  List<String> arguments, {
  required Directory currentDirectory,
  required void Function(String) writeOutput,
  required void Function(String) writeError,
}) async {
  try {
    final command = _parseArguments(arguments, currentDirectory);
    final inventory = await NoticeInventory.collect(
      NoticeInventoryRequest.fromProjectRoot(command.projectRoot),
    );
    final catalog = await _readApprovalCatalog(command.projectRoot);
    final review = await NoticeReview.evaluate(
      inventory: inventory,
      approvals: catalog,
      projectRoot: command.projectRoot,
    );

    switch (command.mode) {
      case _NoticeCliMode.candidate:
        final jsonFile = _resolveProjectOutput(
          command.projectRoot,
          command.target,
        );
        final markdownFile = File(
          path.setExtension(jsonFile.path, '.md'),
        );
        await _writeIfChanged(
          jsonFile,
          '${jsonEncode(review.toCandidateJson())}\n',
        );
        await _writeIfChanged(markdownFile, review.renderCandidateMarkdown());
        writeOutput(
          'third_party_notices.candidate_ready '
          'components=${inventory.components.length}',
        );
      case _NoticeCliMode.output:
        if (!review.isApproved) {
          throw _NoticeCliFailure(
            'third_party_notices.review_required issues=${review.issues.length}',
            65,
          );
        }
        final output = _resolveProjectOutput(
          command.projectRoot,
          command.target,
        );
        final contents = await review.renderReviewedNotices(
          command.projectRoot,
        );
        final changed = await _writeIfChanged(output, contents);
        writeOutput(
          'third_party_notices.${changed ? 'written' : 'unchanged'} '
          'components=${inventory.components.length}',
        );
      case _NoticeCliMode.check:
        if (!review.isApproved) {
          throw _NoticeCliFailure(
            'third_party_notices.review_required issues=${review.issues.length}',
            65,
          );
        }
        final notice = _resolveProjectInput(
          command.projectRoot,
          command.target,
        );
        final expected = await review.renderReviewedNotices(
          command.projectRoot,
        );
        if (await notice.readAsString() != expected) {
          throw const _NoticeCliFailure(
            'third_party_notices.notice_drift',
            65,
          );
        }
        writeOutput(
          'third_party_notices.check_passed '
          'components=${inventory.components.length}',
        );
    }
    return 0;
  } on NoticeInventoryFailure catch (failure) {
    writeError(failure.code);
    return 66;
  } on _NoticeCliFailure catch (failure) {
    writeError(failure.code);
    return failure.exitCode;
  } on FormatException {
    writeError('third_party_notices.malformed_input');
    return 66;
  } on FileSystemException {
    writeError('third_party_notices.io_failed');
    return 74;
  }
}

enum _NoticeCliMode { candidate, output, check }

final class _NoticeCliCommand {
  const _NoticeCliCommand({
    required this.mode,
    required this.projectRoot,
    required this.target,
  });

  final _NoticeCliMode mode;
  final Directory projectRoot;
  final String target;
}

final class _NoticeCliFailure implements Exception {
  const _NoticeCliFailure(this.code, this.exitCode);

  final String code;
  final int exitCode;
}

_NoticeCliCommand _parseArguments(
  List<String> arguments,
  Directory currentDirectory,
) {
  var projectRoot = currentDirectory;
  _NoticeCliMode? mode;
  String? target;
  for (var index = 0; index < arguments.length; index += 2) {
    if (index + 1 >= arguments.length) {
      throw const _NoticeCliFailure('third_party_notices.usage', 64);
    }
    final flag = arguments[index];
    final value = arguments[index + 1];
    if (value.isEmpty) {
      throw const _NoticeCliFailure('third_party_notices.usage', 64);
    }
    switch (flag) {
      case '--project-root':
        final rootPath = path.isAbsolute(value)
            ? value
            : path.join(currentDirectory.path, value);
        projectRoot = Directory(path.normalize(rootPath));
      case '--candidate':
        if (mode != null) {
          throw const _NoticeCliFailure('third_party_notices.usage', 64);
        }
        mode = _NoticeCliMode.candidate;
        target = value;
      case '--output':
        if (mode != null) {
          throw const _NoticeCliFailure('third_party_notices.usage', 64);
        }
        mode = _NoticeCliMode.output;
        target = value;
      case '--check':
        if (mode != null) {
          throw const _NoticeCliFailure('third_party_notices.usage', 64);
        }
        mode = _NoticeCliMode.check;
        target = value;
      default:
        throw const _NoticeCliFailure('third_party_notices.usage', 64);
    }
  }
  if (mode == null || target == null || !projectRoot.existsSync()) {
    throw const _NoticeCliFailure('third_party_notices.usage', 64);
  }
  return _NoticeCliCommand(
    mode: mode,
    projectRoot: projectRoot,
    target: target,
  );
}

Future<NoticeApprovalCatalog> _readApprovalCatalog(
  Directory projectRoot,
) async {
  final file = File(
    path.join(
      projectRoot.path,
      'tool',
      'third_party_notices',
      'approved_components.json',
    ),
  );
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.inputMissing,
    );
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, Object?>) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.malformedInput,
    );
  }
  return NoticeApprovalCatalog.fromJson(decoded);
}

File _resolveProjectInput(Directory root, String requestedPath) {
  final file = _resolveProjectOutput(root, requestedPath);
  if (FileSystemEntity.typeSync(file.path, followLinks: false) !=
      FileSystemEntityType.file) {
    throw const NoticeInventoryFailure(
      NoticeInventoryFailureReason.inputMissing,
    );
  }
  return file;
}

File _resolveProjectOutput(Directory root, String requestedPath) {
  final rootPath = path.normalize(path.absolute(root.path));
  final outputPath = path.normalize(
    path.isAbsolute(requestedPath)
        ? requestedPath
        : path.join(rootPath, requestedPath),
  );
  if (!path.isWithin(rootPath, outputPath)) {
    throw const _NoticeCliFailure(
      'third_party_notices.path_outside_project',
      64,
    );
  }
  final type = FileSystemEntity.typeSync(outputPath, followLinks: false);
  if (type != FileSystemEntityType.notFound &&
      type != FileSystemEntityType.file) {
    throw const _NoticeCliFailure('third_party_notices.output_not_regular', 64);
  }
  return File(outputPath);
}

Future<bool> _writeIfChanged(File output, String contents) async {
  if (output.existsSync() && await output.readAsString() == contents) {
    return false;
  }
  await output.parent.create(recursive: true);
  final temporary = File('${output.path}.tmp');
  final temporaryType = FileSystemEntity.typeSync(
    temporary.path,
    followLinks: false,
  );
  if (temporaryType != FileSystemEntityType.notFound &&
      temporaryType != FileSystemEntityType.file) {
    throw const _NoticeCliFailure('third_party_notices.output_not_regular', 64);
  }
  await temporary.writeAsString(contents, flush: true);
  await temporary.rename(output.path);
  return true;
}
