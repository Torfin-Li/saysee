# Security

Saysee is an early public preview. Local speech recognition does **not** mean all processing is offline: the complete transcription is sent to your selected text-model provider.

## Credentials

Never commit or attach API keys, service-account JSON, private keys, signing certificates, tokens, local logs, recordings, or screenshots containing them. DeepSeek is the only text provider and its keys belong in macOS Keychain. The app does not read local cloud-service credential files or cloud-authentication environment variables. `.gitignore` is a convenience, not a security boundary; staged source and actual release artifacts must both be scanned.

If a credential is exposed, revoke or rotate it with its issuer first. Removing a file or making a repository private does not revoke a leaked credential or erase copies and Git history.

## Reporting

Do not disclose live credentials or a working sensitive-data exploit in a public issue. Use GitHub private vulnerability reporting once it is enabled on the public repository. Until a private reporting channel is available, do not upload sensitive evidence to public issues; public reports should contain only a sanitized description and synthetic reproduction data.

The first public release must enable private vulnerability reporting and confirm the maintainer's reporting channel. No third-party security audit or response-time SLA is claimed.

## Release checks

- Export and scan the exact Git index with `scripts/audit_public.py` and gitleaks.
- Scan Git history before the first push and on CI; adding an ignore rule cannot remove an already committed secret.
- Generate the app in an empty staging directory, include only explicit model and application resources, preserve third-party notices, strip debug information, and map build paths.
- Audit the resulting app separately. Tensor weights are restricted to a known path but are not text secret-scanned; fetch them from the pinned upstream revision.
- A valid ad-hoc signature is a development check, not Developer ID signing or Apple notarization.
