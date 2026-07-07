defmodule PhoenixEmail do
  @moduledoc """
  Build emails with HEEx components. A port of
  [react-email](https://react.email) for Phoenix.

  Define emails as regular function components and render them to an HTML
  string (or a plain text version for multipart emails):

      defmodule MyApp.Emails do
        use PhoenixEmail

        def welcome(assigns) do
          ~H\"\"\"
          <.email>
            <.head />
            <.preview>You're in — let's get you set up</.preview>
            <.body style="background-color:#ffffff;font-family:sans-serif">
              <.container>
                <.heading as="h1">Hello {@name}</.heading>
                <.text>Thanks for signing up.</.text>
                <.button href={@url} style="background-color:#5e6ad2;color:#fff;padding:12px 20px;border-radius:8px">
                  Get started
                </.button>
                <.hr />
                <.link href="https://example.com">example.com</.link>
              </.container>
            </.body>
          </.email>
          \"\"\"
        end
      end

      html = PhoenixEmail.render(&MyApp.Emails.welcome/1, %{name: "Ada", url: "https://example.com/start"})
      text = PhoenixEmail.render(&MyApp.Emails.welcome/1, %{name: "Ada", url: "https://example.com/start"}, plain_text: true)

  `use PhoenixEmail` pulls in `Phoenix.Component` and imports all the
  components from `PhoenixEmail.Components` (Phoenix's `link/1` is excluded
  in favor of the email one).
  """

  alias Phoenix.HTML.Safe
  alias PhoenixEmail.PlainText

  @doctype ~s(<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">)

  defmacro __using__(opts) do
    quote do
      use Phoenix.Component, unquote(opts)
      import Phoenix.Component, except: [link: 1]
      import PhoenixEmail.Components
    end
  end

  @doc """
  Renders an email to a string.

  Accepts either the result of a `~H` template or a function component plus
  its assigns. Returns the HTML prefixed with the XHTML 1.0 Transitional
  doctype (the same one react-email emits).

  ## Options

    * `:plain_text` - when `true`, returns a plain text version of the email
      instead of HTML, for the `text/plain` part of multipart messages.

  """
  def render(rendered_or_fun, assigns_or_opts \\ [])

  def render(fun, opts) when is_function(fun, 1) and is_list(opts) do
    render(fun, %{}, opts)
  end

  def render(fun, assigns) when is_function(fun, 1) and is_map(assigns) do
    render(fun, assigns, [])
  end

  def render(rendered, opts) when is_list(opts) do
    do_render(rendered, opts)
  end

  @doc """
  Renders a function component to a string with the given assigns.

  See `render/2` for the options.
  """
  def render(fun, assigns, opts) when is_function(fun, 1) do
    assigns
    |> Map.new()
    # so assign/2,3 and assign_new/3 work inside email functions
    |> Map.put_new(:__changed__, nil)
    |> fun.()
    |> do_render(opts)
  end

  defp do_render(rendered, opts) do
    html =
      rendered
      |> Safe.to_iodata()
      |> IO.iodata_to_binary()

    if Keyword.get(opts, :plain_text, false) do
      PlainText.convert(html)
    else
      @doctype <> html
    end
  end
end
