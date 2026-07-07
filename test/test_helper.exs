# The :tailwind_bin tests shell out to the real tailwindcss binary (or npx).
# Run them with: mix test --include tailwind_bin
ExUnit.start(exclude: [:tailwind_bin])
