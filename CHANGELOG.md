# Changelog

## 0.1.0 — Unreleased public preview

- Native macOS menu-bar app with Fn / alternate hotkey capture, manual stop and cancellation.
- Local Qwen3 ASR 1.7B 6-bit transcription on Apple Silicon via MLX / Metal.
- Thirty-second transcription work overlaps long recordings; a sound-activity gate controls the compact recording indicator.
- Blocking DeepSeek-only text refinement with contextual correction, concise wording and plain-text structure.
- Conservative editable-target delivery, clipboard fallback, result card and retry.
- Local Keychain credentials, permission controls and body-free stage timing diagnostics.
- Public-source cleanup, licensing, documentation and staged-source / app publication audits.

No GitHub release, Developer ID signing, notarization or DMG distribution has been completed yet.

### Local preview refinement

- Removed the alternate cloud provider, local service-account authentication, environment reads and related CLI/configuration paths; legacy app settings are purged without touching external files.
- Quiet listening uses low static dashes; speech uses bright, larger staggered motion; processing uses a complete ring with a rotating highlighted arc.
