# Privacy

Loquiris records reliably without an account or network connection. Choosing
remote transcription authorizes uploading a copy of that meeting's finalized
audio to the server the user configures in Settings. New recording setup offers
recording-only and remote transcription. Historical recordings are not uploaded
automatically. Network permissions support this explicit transfer; there is no
analytics, advertising, remote configuration or remote crash upload.

Original recordings remain in application-private storage on the phone. Upload
and model failures do not stop recording or delete originals. Remote transcript
versions, their source metadata and separately saved human corrections are stored
locally and remain readable/exportable after the server copy expires. Free-form
corrections have no automatic word alignment; original subtitle exports retain
the original timestamped machine text, while text/JSON exports include corrections.

The configured server receives the selected audio, opaque meeting/run identities,
checksums, media geometry and chosen model profile. The supplied self-hosted server
does not forward audio to another provider. An administrator can inspect its
storage. Default retention is 24 hours after upload activity, and 24 hours after a
job reaches a terminal state; shared uploaded audio is retained while another
referencing job still needs it. Cancellation is local first and remote cleanup
requires network access. A server outage can delay remote cancellation or deletion.
Actual deadlines are returned by the server; remote expiry never deletes the
phone's original audio or already imported transcript versions.

HTTPS uses normal certificate and hostname verification. HTTP is available only
for explicit private IPv4 addresses (and 127.0.0.1), for use on a trusted LAN.
HTTP sends both audio and access tokens without transport encryption; other
participants on the network may observe them. Public HTTP, redirects, URL user
information, query strings and non-root endpoint paths are rejected. Android
cleartext permission enables this transport; the app checks the destination.

Saving a default connection does not create a meeting or authorize a new upload.
It resumes only previously opted-in tasks waiting for configuration. Restored
tasks remain disabled until explicit user action. The default connection is
stored outside backups alongside the encrypted token reference.

Access tokens are encrypted with Android Keystore and stored under no-backup
private storage. Database/task records contain only an opaque credential reference.
Custom backups preserve recordings, remote results and corrections, exclude tokens,
and disable restored remote work until a new explicit user action. Backups are not
password encrypted; protect exported backup files as sensitive content.

Deleting a meeting first moves it to local trash unless permanent deletion is
explicitly confirmed. Permanent deletion removes data controlled locally by
Loquiris; copies previously exported, backed up or sent to a server have separate
lifecycles. Cancel outstanding remote tasks before permanent deletion if server
cancellation is required. The self-hosted server also performs retention cleanup.

Uninstalling removes app-private data and credentials. Previously exported or
backed-up documents remain in their selected storage providers. Loquiris disables
Android cloud backup and excludes application data from Android 12+ cloud and
device transfer rules. Manufacturer implementations of these controls can vary.

Local diagnostic logs exclude audio, full transcripts, titles, speaker names,
tokens and sensitive paths. The supplied API disables access logs. Operators must
apply the same content/credential exclusions to any additional infrastructure logs.
