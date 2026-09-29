# Privacy

Loquiris is designed to operate without an account or network connection. Release builds do not request Android network permissions and do not include analytics, advertising, remote configuration, cloud inference, or remote crash upload.

Meetings, transcripts, revisions, models, and working data default to application-private storage. Files leave that storage only after an explicit export or backup action. MVP backups are not password encrypted and therefore display a sensitive-data warning.

Deleting a meeting first moves it to a seven-day local trash unless permanent deletion is explicitly confirmed. Uninstalling removes app-private data; copies previously exported to another location remain outside Loquiris control.

Diagnostic logs are local, bounded to seven days or 10 MiB, and exclude audio, complete transcript content, titles, speaker names, and sensitive paths.
