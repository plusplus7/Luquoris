import 'package:loquiris/data/database/app_database.dart';

/// Atomic write boundary for one immutable model manifest aggregate.
final class ModelWriteTransactions {
  /// Creates model write boundaries over [database].
  const ModelWriteTransactions(this.database);

  /// Database that owns the transaction and all affected tables.
  final AppDatabase database;

  /// Inserts a manifest, its capabilities, and enabled modes atomically.
  Future<void> installManifest(
    ModelManifestsCompanion manifest, {
    required List<ModelCapabilityEntriesCompanion> capabilities,
    required List<ModelModeEntriesCompanion> modes,
  }) async {
    if (!manifest.id.present) {
      throw ArgumentError('manifest.id must be present');
    }
    final modelId = manifest.id.value;
    for (final capability in capabilities) {
      if (!capability.modelId.present || capability.modelId.value != modelId) {
        throw ArgumentError('capability.modelId must equal manifest.id');
      }
    }
    for (final mode in modes) {
      if (!mode.modelId.present || mode.modelId.value != modelId) {
        throw ArgumentError('mode.modelId must equal manifest.id');
      }
    }

    await database.transaction(() async {
      await database.into(database.modelManifests).insert(manifest);
      for (final capability in capabilities) {
        await database.into(database.modelCapabilityEntries).insert(capability);
      }
      for (final mode in modes) {
        await database.into(database.modelModeEntries).insert(mode);
      }
    });
  }
}
