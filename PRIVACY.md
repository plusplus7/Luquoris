# Privacy

Loquiris is designed to operate without an account or network connection. Release builds do not request Android network permissions and do not include analytics, advertising, remote configuration, cloud inference, or remote crash upload.

Meetings, authoritative recordings, transcripts, revisions, models, databases, private backups, caches, and working data default to application-private storage. Files leave that storage only after an explicit export or backup action. MVP backups are not password encrypted and therefore display a sensitive-data warning.

Deleting a meeting first moves it to a seven-day local trash unless permanent deletion is explicitly confirmed. Permanent deletion removes the meeting data controlled by Loquiris, but it cannot remove copies that were previously exported or backed up to user-selected destinations.

Uninstalling Loquiris removes its app-private database, recordings, transcripts, revisions, models, caches, working files, and private backup packages. Documents previously exported or backed up through the Android system picker remain in their user-selected storage provider and must be deleted there by the user.

Loquiris disables Android cloud backup. On Android 12 and newer it also supplies explicit rules excluding every supported app-data domain from cloud backup and device-to-device transfer. Android documents that some device manufacturers may ignore an application's `allowBackup="false"` choice during device-to-device migration, so Loquiris cannot guarantee that every manufacturer implements this opt-out correctly. Reinstallation is not intended to restore private Loquiris data through Android backup infrastructure.

Diagnostic logs are local, bounded to seven days or 10 MiB, and exclude audio, complete transcript content, titles, speaker names, and sensitive paths.
