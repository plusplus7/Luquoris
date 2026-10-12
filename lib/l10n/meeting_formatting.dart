import 'package:flutter/material.dart';
import 'package:loquiris/l10n/app_localizations.dart';

/// Builds the durable default title used when recording starts without one.
String localizedMeetingDefaultTitle(
  BuildContext context,
  DateTime localDateTime,
) {
  final material = MaterialLocalizations.of(context);
  return AppLocalizations.of(context).meetingDefaultTitle(
    material.formatFullDate(localDateTime),
    material.formatTimeOfDay(TimeOfDay.fromDateTime(localDateTime)),
  );
}
