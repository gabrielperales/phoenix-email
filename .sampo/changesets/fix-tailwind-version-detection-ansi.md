---
hex/phoenix_email: patch
---

Fixed Tailwind version detection when the CLI colorizes its output (e.g. on GitHub Actions runners): the compiler now runs the binary with `NO_COLOR=1` and strips ANSI escapes before parsing `--help`, so `mix phoenix_email.tailwind` no longer fails with "could not detect the tailwindcss version".
