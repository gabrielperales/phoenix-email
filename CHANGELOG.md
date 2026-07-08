# phoenix_email

## 0.1.1 — 2026-07-08

### Patch changes

- [98e72de](https://github.com/gabrielperales/phoenix-email/commit/98e72de5e98f55c61ac6df82d1c8eecbc2e70e00) Fixed Tailwind version detection when the CLI colorizes its output (e.g. on GitHub Actions runners): the compiler now runs the binary with `NO_COLOR=1` and strips ANSI escapes before parsing `--help`, so `mix phoenix_email.tailwind` no longer fails with "could not detect the tailwindcss version". — Thanks Gabriel Perales!

## 0.1.0 — 2026-07-09

Initial release.

- Email components as HEEx function components
- Tailwind class compilation to inline styles
- Plain-text rendering
- Swoosh integration
