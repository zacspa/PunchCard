# PunchCard — Working Notes

## Preferences

**Always prefer local / vertically-integrated solutions over outsourcing to a service.** When solving a problem — storage, auth, background jobs, builds, anything — start from what can run on the user's own machines (CLI, device, self-hosted) and only reach for a managed service when local is genuinely worse, not just less convenient. Happy to hear about managed options and their tradeoffs; just don't lead with them.

Concretely:
- Prefer SQLite / local JSON / flat files over hosted DBs.
- Prefer local builds (Gradle / Xcode / swift build) over cloud builds when the tooling is already installed.
- Prefer self-owned webhooks and Apps Script over third-party SaaS middleware.
- Prefer library code over API calls; prefer direct SDK over wrapper service.
- Prefer auth patterns that don't require a server (shared secret, user-owned tokens, device pairing) over OAuth-gated flows.

If a service really is the best answer, say so explicitly and name what the local alternative would cost.
