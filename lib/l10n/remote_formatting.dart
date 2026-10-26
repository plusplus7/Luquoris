import 'package:flutter/material.dart';
import 'package:loquiris/l10n/app_localizations.dart';

/// Formats the server's actual UTC deadline using the current local calendar.
String localizedRemoteExpiry(BuildContext context, int epochMilliseconds) {
  final local = DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds,
  ).toLocal();
  final material = MaterialLocalizations.of(context);
  return AppLocalizations.of(context).remoteExpires(
    '${material.formatFullDate(local)} ${material.formatTimeOfDay(TimeOfDay.fromDateTime(local))}',
  );
}
