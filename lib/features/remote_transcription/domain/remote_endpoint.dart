/// Accepts an authenticated origin, with HTTP restricted to explicit LAN IPs.
bool isRemoteEndpoint(String value) {
  if (value != value.trim() ||
      value.contains(RegExp(r'[\s\x00-\x1f\x7f%@]')) ||
      value.runes.any((rune) => rune > 127)) {
    return false;
  }
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.host.isEmpty ||
      uri.authority.contains('@') ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return false;
  }
  try {
    if (uri.port < 1 || uri.port > 65535) return false;
  } on FormatException {
    return false;
  }
  if (uri.scheme == 'https') return true;
  if (uri.scheme != 'http') return false;
  final parts = uri.host.split('.');
  if (parts.length != 4) return false;
  final bytes = <int>[];
  for (final part in parts) {
    final number = int.tryParse(part);
    if (number == null || number < 0 || number > 255 || '$number' != part) {
      return false;
    }
    bytes.add(number);
  }
  return uri.host == '127.0.0.1' ||
      bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
}
