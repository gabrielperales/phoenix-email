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

And hand both to your mailer, for example with [Swoosh](https://hexdocs.pm/swoosh):

```elixir
import Swoosh.Email

new()
|> to({user.name, user.email})
|> from({"MyApp", "hello@myapp.com"})
|> subject("Welcome!")
|> html_body(html)
|> text_body(text)
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

All components accept a `style` attribute with an inline CSS string. Component defaults are merged with your style, yours last, so you can override anything by cascade. Any other HTML attribute is forwarded to the underlying tag.

## Styling

There is no style-object DSL: styles are plain CSS strings, inline, exactly what email clients require.

```heex
<.text style="color:#525f7f;font-size:16px">…</.text>
```

## Plain text

`PhoenixEmail.render(fun, assigns, plain_text: true)` produces the `text/plain` version for multipart emails: tags are stripped, links become `label [url]`, dividers become dashes, and the preview text is excluded.

## Development

```sh
mix deps.get
mix test
mix credo --strict
mix format --check-formatted
```

## License

MIT
