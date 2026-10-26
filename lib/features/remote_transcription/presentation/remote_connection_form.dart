import 'package:flutter/material.dart';
import 'package:loquiris/features/remote_transcription/domain/remote_endpoint.dart';
import 'package:loquiris/l10n/app_localizations.dart';

/// Secret entry lives only in short-lived controllers, never a provider state.
final class RemoteConnectionForm extends StatefulWidget {
  /// Submits only validated origin and token input.
  const RemoteConnectionForm({
    required this.onSubmit,
    required this.busy,
    this.initialEndpoint = '',
    super.key,
  });

  /// Commits the connection through the ViewModel's native service seam.
  final void Function(String endpoint, String token) onSubmit;

  /// Prevents duplicate configuration commits.
  final bool busy;

  /// Previously saved origin; the secret is never prefilled.
  final String initialEndpoint;
  @override
  State<RemoteConnectionForm> createState() => _RemoteConnectionFormState();
}

final class _RemoteConnectionFormState extends State<RemoteConnectionForm> {
  final _key = GlobalKey<FormState>();
  late final _endpoint = TextEditingController(text: widget.initialEndpoint);
  final _token = TextEditingController();
  @override
  void dispose() {
    _endpoint.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _key,
      child: Column(
        children: [
          TextFormField(
            key: const Key('remote-endpoint'),
            controller: _endpoint,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: l10n.remoteEndpoint),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              return isRemoteEndpoint(value?.trim() ?? '')
                  ? null
                  : l10n.remoteInputInvalid;
            },
          ),
          TextFormField(
            key: const Key('remote-token'),
            controller: _token,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(labelText: l10n.remoteToken),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) =>
                value != null &&
                    value.length >= 32 &&
                    value.length <= 4096 &&
                    !value.contains(RegExp(r'[\r\n]'))
                ? null
                : l10n.remoteInputInvalid,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: widget.busy
                ? null
                : () {
                    if (!_key.currentState!.validate()) return;
                    final token = _token.text;
                    _token.clear();
                    widget.onSubmit(_endpoint.text.trim(), token);
                  },
            child: Text(l10n.remoteConfigure),
          ),
        ],
      ),
    );
  }
}
