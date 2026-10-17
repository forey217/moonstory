# Changelog

## 0.1.1 — 2026-10-17

- Preflight the exact JSON-encoded save size before serializing the full action journal. Long, repeatedly selected choice identifiers cannot trigger an oversized joined save allocation.
- Add a regression case with a 120,000-character choice id and twenty legal transitions.
- Keep the language, save format and public API compatible with 0.1.0.

## 0.1.0 — 2026-10-17

- Initial MoonStory 1 compiler, typed expression evaluator and immutable runtime.
- Guarded choices, host events, structural diagnostics and replay saves.
- CLI, local authoring studio, three complete scenarios and external SDK consumer.
