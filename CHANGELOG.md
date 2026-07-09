# phoenix_email

## 0.1.2 — 2026-07-09

### Patch changes

- [1b1b156](https://github.com/gabrielperales/phoenix-email/commit/1b1b15610bca1f199632663fb2e8f568e5bef170) Fixed the compiled Tailwind map not being found inside releases: a relative `tailwind_map_path` resolves against the release cwd (`/`), so `PhoenixEmail.Tailwind` silently loaded an empty map and every email rendered unstyled. Set the new `:otp_app` config key and relative paths now resolve against your application's `priv` directory via `Application.app_dir/2`, which works in dev, test, and releases alike:
  
  ```elixir
  config :phoenix_email,
    otp_app: :my_app,
    tailwind_map_path: "priv/phoenix_email/tailwind.map"
  ```
  
  Absolute paths are left untouched, and without `:otp_app` the previous cwd-relative behaviour is unchanged. — Thanks Gabriel Perales!

## 0.1.1 — 2026-07-08

### Patch changes

- [98e72de](https://github.com/gabrielperales/phoenix-email/commit/98e72de5e98f55c61ac6df82d1c8eecbc2e70e00) Fixed Tailwind version detection when the CLI colorizes its output (e.g. on GitHub Actions runners): the compiler now runs the binary with `NO_COLOR=1` and strips ANSI escapes before parsing `--help`, so `mix phoenix_email.tailwind` no longer fails with "could not detect the tailwindcss version". — Thanks Gabriel Perales!

## 0.1.0 — 2026-07-09

Initial release.

- Email components as HEEx function components
- Tailwind class compilation to inline styles
- Plain-text rendering
- Swoosh integration
