# PhoenixEmail

Build emails with HEEx components. A port of [react-email](https://react.email) for Phoenix.

Write emails as regular [Phoenix function components](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) and render them to HTML that works across email clients (Gmail, Outlook, Apple Mail, …): table-based layout, inline styles, and MSO conditional comments — the same output react-email produces.

## Installation

Add `phoenix_email` to your dependencies:

```elixir
def deps do
  [
    {:phoenix_email, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
defmodule MyApp.Emails do
  use PhoenixEmail

  def welcome(assigns) do
    ~H"""
    <.email>
      <.head />
      <.preview>You're in — let's get you set up</.preview>
      <.body style="background-color:#ffffff;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif">
        <.container style="padding:20px 48px">
          <.heading as="h1" style="font-size:24px;color:#1a1a1a">Hello {@name}</.heading>
          <.text style="color:#525f7f">Thanks for signing up. Click the button below to get started.</.text>
          <.button href={@url} style="background-color:#5e6ad2;color:#ffffff;padding:12px 20px;border-radius:8px;font-size:14px">
            Get started
          </.button>
          <.hr style="margin:24px 0" />
          <.link href="https://example.com" style="font-size:12px">example.com</.link>
        </.container>
      </.body>
    </.email>
    """
  end
end
```

Render it to a string:

```elixir
html = PhoenixEmail.render(&MyApp.Emails.welcome/1, %{name: "Ada", url: "https://example.com/start"})
text = PhoenixEmail.render(&MyApp.Emails.welcome/1, %{name: "Ada", url: "https://example.com/start"}, plain_text: true)
```

And hand both to your mailer. With the optional [Swoosh](https://hexdocs.pm/swoosh) integration (add `{:swoosh, "~> 1.16"}` to your deps):

```elixir
import Swoosh.Email

new()
|> to({user.name, user.email})
|> from({"MyApp", "hello@myapp.com"})
|> subject("Welcome!")
|> PhoenixEmail.Swoosh.render_body(&MyApp.Emails.welcome/1, %{name: user.name, url: url})
```

## Components

| Component | Renders | Notes |
| --- | --- | --- |
| `<.email>` | `<html>` | Root element; `lang` and `dir` attributes |
| `<.head>` | `<head>` | Content-type + Apple reformatting meta tags |
| `<.preview>` | hidden `<div>` | Inbox preview text, padded to 150 chars |
| `<.body>` | `<body>` | |
| `<.container>` | centered `<table>` | Max width 37.5em (600px) |
| `<.section>` | full-width `<table>` | Groups content into blocks |
| `<.row>` / `<.column>` | `<table>` / `<td>` | Multi-column layout |
| `<.heading>` | `h1`–`h6` (`as` attr) | Margin shorthands `m`, `mx`, `my`, `mt`, `mr`, `mb`, `ml` |
| `<.text>` | `<p>` | Email-safe font-size/line-height defaults |
| `<.link>` | `<a>` | Opens in a new tab by default |
| `<.button>` | `<a>` | Parses `padding` from `style` and emits the MSO hack so Outlook keeps the button size |
| `<.img>` | `<img>` | `display:block` + border/outline resets |
| `<.hr>` | `<hr>` | |
| `<.font>` | `<style>` with `@font-face` | Web fonts with `mso-font-alt` fallback; place inside `<.head>` |
| `<.code_inline>` | `<code>` | |
| `<.code_block>` | `<pre><code>` | Inline-styled syntax highlighting via optional [makeup](https://hex.pm/packages/makeup) |
| `<.markdown>` | styled HTML | Markdown with per-tag inline styles via optional [earmark_parser](https://hex.pm/packages/earmark_parser) |

All components accept a `style` attribute with an inline CSS string or a style object. Component defaults are merged with your style, yours last, so you can override anything by cascade. Any other HTML attribute is forwarded to the underlying tag.

## Styling

Styles always render as plain inline CSS, exactly what email clients require. You can write them as CSS strings:

```heex
<.text style="color:#525f7f;font-size:16px">…</.text>
```

or as style objects — maps or keyword lists:

```heex
<.text style={%{color: "#525f7f", font_size: 16}}>…</.text>
<.section style={[padding: 24, background_color: "#f6f8fa"]}>…</.section>
```

Property names may be atoms or strings in snake_case, camelCase, or kebab-case (`:font_size`, `"fontSize"`, and `"font-size"` all work), so react-email styles can be pasted as-is. Numbers get a `px` suffix except for unitless properties such as `line-height`, `opacity`, or `font-weight`. Entries with a `nil` or `false` value are dropped, which makes conditional declarations easy:

```heex
<.text style={%{color: "#525f7f", font_weight: @urgent && 700}}>…</.text>
```

Maps render their declarations sorted by property so output is deterministic; use a keyword list when declaration order matters (e.g. a shorthand followed by a longhand override).

## Tailwind classes

Every visual component also accepts a `class` attribute with Tailwind utilities — the equivalent of react-email's `<Tailwind>` wrapper, but compiled **at build time** instead of on every render:

```sh
mix phoenix_email.tailwind
```

The task scans your sources for classes (Tailwind's own content scanning), runs the real `tailwindcss` binary, converts the CSS to email-safe inline declarations (`rem` → `px`, `rgb()` → hex), and stores a class → style map under `priv/`. Rendering a `class` is then a map lookup — no external processes per email:

```heex
<.container class="border border-gray-200 rounded-lg p-5 max-w-[465px]">
  <.button href={@url} class="bg-black text-white text-xs font-semibold rounded px-5 py-3">
    Join the team
  </.button>
</.container>
```

Because the real compiler runs, your `tailwind.config.js` theme, custom colors, and arbitrary values all work. Configuration:

```elixir
config :phoenix_email,
  tailwind_content: ["lib/**/*.ex"],                    # files to scan
  tailwind_config: "assets/tailwind.config.js",         # optional, your own config
  tailwind_map_path: "priv/phoenix_email/tailwind.map", # compiled map location
  tailwind_bin: "/path/to/tailwindcss"                  # optional, see below
```

The binary is resolved from `:tailwind_bin`, the [tailwind](https://hex.pm/packages/tailwind) hex package (what new Phoenix projects ship, v4 by default), `tailwindcss` in `$PATH`, or — as a last resort — a Tailwind v4 CLI installed once with npm into a cached directory. **Both Tailwind v3 and v4 binaries work**: the version is detected and the post-processing adapts (v4's `oklch()` colors, `calc(var(--spacing) * n)` spacing, `calc(infinity * 1px)` radii, `color-mix()` opacity modifiers, and logical properties are all resolved to email-safe values). With v4 you can also point `:tailwind_config` at your CSS entry point (`@theme`) instead of a JS config.

Re-run the task after changing classes (wire it into your `assets.build`/`test` aliases). Same rules as Tailwind itself: classes must be literal strings in your source — no `"bg-#{color}"` — and variants (`sm:`, `hover:`) are skipped since they can't be inlined. `class` merges between component defaults and `style`, so explicit styles always win.

## Optional dependencies

| Feature | Add to your deps |
| --- | --- |
| `<.code_block>` highlighting | `{:makeup, "~> 1.1"}` plus a lexer, e.g. `{:makeup_elixir, "~> 1.0"}` |
| `<.markdown>` | `{:earmark_parser, "~> 1.4"}` |
| `PhoenixEmail.Swoosh.render_body/3` | `{:swoosh, "~> 1.16"}` |

Everything degrades gracefully: without makeup the code block renders unstyled, without earmark_parser the markdown component raises with instructions, and `PhoenixEmail.Swoosh` is only compiled when swoosh is present.

## Plain text

`PhoenixEmail.render(fun, assigns, plain_text: true)` produces the `text/plain` version for multipart emails: tags are stripped, links become `label [url]`, dividers become dashes, and the preview text is excluded.

## Development

```sh
mix deps.get
mix test
mix credo --strict
mix format --check-formatted
```

### Releasing

Releases are automated with [Sampo](https://github.com/bruits/sampo). If your PR
changes user-facing behavior, add a changeset before opening it:

```sh
sampo add
```

Pick the bump level (`patch` / `minor` / `major`) and describe the change from the
user's perspective — that text goes verbatim into `CHANGELOG.md`. The changeset is
a small markdown file under `.sampo/changesets/` that gets committed with your PR.
Docs-only or CI-only changes don't need one.

On every push to `main`, a GitHub Action collects pending changesets into a
"Release" PR that bumps the version in `mix.exs` and updates `CHANGELOG.md`.
Merging that PR publishes the package to Hex and creates the git tag and GitHub
Release automatically.

## License

MIT
