---
hex/phoenix_email: patch
---

Fixed the compiled Tailwind map not being found inside releases: a relative `tailwind_map_path` resolves against the release cwd (`/`), so `PhoenixEmail.Tailwind` silently loaded an empty map and every email rendered unstyled. Set the new `:otp_app` config key and relative paths now resolve against your application's `priv` directory via `Application.app_dir/2`, which works in dev, test, and releases alike:

```elixir
config :phoenix_email,
  otp_app: :my_app,
  tailwind_map_path: "priv/phoenix_email/tailwind.map"
```

Absolute paths are left untouched, and without `:otp_app` the previous cwd-relative behaviour is unchanged.
