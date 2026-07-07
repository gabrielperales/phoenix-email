defmodule PhoenixEmail.Components do
  @moduledoc """
  HEEx function components for building emails, ported from
  [react-email](https://react.email).

  Every component renders client-compatible HTML (tables for layout, inline
  styles, MSO conditional comments for Outlook) and accepts a `style`
  attribute with an inline CSS string. Default styles are merged with the
  user's, user styles last so they win by cascade. All other HTML attributes
  are forwarded to the underlying tag.

      use PhoenixEmail

      def welcome(assigns) do
        ~H\"\"\"
        <.email>
          <.head />
          <.preview>What the inbox shows next to the subject</.preview>
          <.body>
            <.container>
              <.heading as="h1">Hello</.heading>
              <.text>Welcome aboard.</.text>
              <.button href="https://example.com" style="padding:12px 20px">Start</.button>
            </.container>
          </.body>
        </.email>
        \"\"\"
      end
  """

  use Phoenix.Component

  import Phoenix.Component, except: [link: 1]

  alias Phoenix.HTML.Safe
  alias PhoenixEmail.Highlight
  alias PhoenixEmail.Markdown
  alias PhoenixEmail.Style
  alias PhoenixEmail.Tailwind

  @preview_max_length 150

  @doc """
  Root element of the email. Renders the `<html>` tag.

  Named `email` instead of `html` to read naturally alongside the other
  components.
  """
  attr(:lang, :string, default: "en")
  attr(:dir, :string, default: "ltr")
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def email(assigns) do
    ~H"""
    <html dir={@dir} lang={@lang} {@rest}>{render_slot(@inner_block)}</html>
    """
  end

  @doc """
  The `<head>` of the email, with the content-type and Apple message
  reformatting meta tags. Put `<.font>` and extra meta tags in the slot.
  """
  attr(:rest, :global)
  slot(:inner_block)

  def head(assigns) do
    ~H"""
    <head {@rest}>
      <meta content="text/html; charset=UTF-8" http-equiv="Content-Type" />
      <meta name="x-apple-disable-message-reformatting" />
      {render_slot(@inner_block)}
    </head>
    """
  end

  @doc """
  The `<body>` of the email.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def body(assigns) do
    assigns = put_style(assigns, class_style(assigns))

    ~H"""
    <body {@attrs}>{render_slot(@inner_block)}</body>
    """
  end

  @doc """
  Preview text shown by inboxes next to the subject line.

  Renders a hidden `div` with the slot text (capped at #{@preview_max_length}
  characters) padded with invisible characters so clients don't leak the
  email body into the preview. Excluded from the plain text version.
  """
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def preview(assigns) do
    text =
      assigns.inner_block
      |> slot_text()
      |> String.trim()
      |> String.slice(0, @preview_max_length)

    whitespace =
      String.duplicate("\u00A0\u200C", max(@preview_max_length - String.length(text), 0))

    content =
      Phoenix.HTML.raw([text, ~s(<div data-skip-in-text="true">), whitespace, "</div>"])

    assigns = assign(assigns, :content, content)

    ~H"""
    <div data-skip-in-text="true" style="display:none;overflow:hidden;line-height:1px;opacity:0;max-height:0;max-width:0" {@rest}>{@content}</div>
    """
  end

  @doc """
  Centered layout table that caps the email width at 37.5em (600px).
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def container(assigns) do
    ~H"""
    <table
      align="center"
      width="100%"
      border="0"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      style={Style.merge("max-width:37.5em", class_style(assigns))}
      {@rest}
    >
      <tbody>
        <tr style="width:100%">
          <td>{render_slot(@inner_block)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Full-width layout table used to group content into blocks.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def section(assigns) do
    assigns = put_style(assigns, class_style(assigns))

    ~H"""
    <table
      align="center"
      width="100%"
      border="0"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      {@attrs}
    >
      <tbody>
        <tr>
          <td>{render_slot(@inner_block)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  A table row. Put `<.column>` components in the slot.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def row(assigns) do
    assigns = put_style(assigns, class_style(assigns))

    ~H"""
    <table
      align="center"
      width="100%"
      border="0"
      cellpadding="0"
      cellspacing="0"
      role="presentation"
      {@attrs}
    >
      <tbody style="width:100%">
        <tr style="width:100%">{render_slot(@inner_block)}</tr>
      </tbody>
    </table>
    """
  end

  @doc """
  A column (`<td>`) inside a `<.row>`.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global, include: ~w(align valign width height bgcolor))
  slot(:inner_block, required: true)

  def column(assigns) do
    assigns = put_style(assigns, class_style(assigns))

    ~H"""
    <td {@attrs}>{render_slot(@inner_block)}</td>
    """
  end

  @doc """
  A heading (`h1`–`h6`, chosen with `as`).

  Margins can be set with the shorthand attributes `m`, `mx`, `my`, `mt`,
  `mr`, `mb` and `ml`. Numbers are treated as px; strings are used as-is.
  """
  attr(:as, :string, default: "h1", values: ~w(h1 h2 h3 h4 h5 h6))
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:m, :any, default: nil)
  attr(:mx, :any, default: nil)
  attr(:my, :any, default: nil)
  attr(:mt, :any, default: nil)
  attr(:mr, :any, default: nil)
  attr(:mb, :any, default: nil)
  attr(:ml, :any, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def heading(assigns) do
    assigns =
      assign(assigns, :computed_style, Style.merge(margin_style(assigns), class_style(assigns)))

    ~H"""
    <.dynamic_tag tag_name={@as} style={@computed_style} {@rest}>{render_slot(@inner_block)}</.dynamic_tag>
    """
  end

  @doc """
  A paragraph of text.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def text(assigns) do
    ~H"""
    <p style={Style.merge("font-size:14px;line-height:24px;margin:16px 0", class_style(assigns))} {@rest}>{render_slot(@inner_block)}</p>
    """
  end

  @doc """
  A hyperlink, opening in a new tab by default.
  """
  attr(:href, :string, required: true)
  attr(:target, :string, default: "_blank")
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def link(assigns) do
    ~H"""
    <a
      href={@href}
      target={@target}
      style={Style.merge("color:#067df7;text-decoration-line:none", class_style(assigns))}
      {@rest}
    >{render_slot(@inner_block)}</a>
    """
  end

  @doc """
  A link styled as a button.

  Padding declared in `style` (shorthand or longhands, px) is parsed and
  reproduced with MSO conditional comments so the button keeps its size in
  Outlook, which ignores padding on `<a>` tags — the same hack react-email
  uses.
  """
  attr(:href, :string, required: true)
  attr(:target, :string, default: nil)
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def button(assigns) do
    base_style = class_style(assigns)
    {pt, pr, pb, pl} = Style.padding(base_style)

    computed_style =
      Style.merge(
        base_style,
        "line-height:100%;text-decoration:none;display:inline-block;max-width:100%;" <>
          "mso-padding-alt:0px;padding:#{pt}px #{pr}px #{pb}px #{pl}px"
      )

    mso_before =
      ~s(<!--[if mso]><i style="mso-font-width:#{pl * 5}%;mso-text-raise:#{Style.pt(pt + pb)}" hidden>&#8202;</i><![endif]-->)

    mso_after =
      ~s(<!--[if mso]><i style="mso-font-width:#{pr * 5}%" hidden>&#8202;&#8203;</i><![endif]-->)

    assigns =
      assigns
      |> assign(:computed_style, computed_style)
      |> assign(:mso_before, Phoenix.HTML.raw(mso_before))
      |> assign(:mso_after, Phoenix.HTML.raw(mso_after))
      |> assign(
        :inner_style,
        "max-width:100%;display:inline-block;line-height:120%;mso-padding-alt:0px;" <>
          "mso-text-raise:#{Style.pt(pb)}"
      )

    ~H"""
    <a href={@href} target={@target} style={@computed_style} {@rest}><span>{@mso_before}</span><span style={@inner_style}>{render_slot(@inner_block)}</span><span>{@mso_after}</span></a>
    """
  end

  @doc """
  An image with the resets email clients need.
  """
  attr(:src, :string, required: true)
  attr(:alt, :string, default: nil)
  attr(:width, :any, default: nil)
  attr(:height, :any, default: nil)
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)

  def img(assigns) do
    ~H"""
    <img
      src={@src}
      alt={@alt}
      width={@width}
      height={@height}
      style={Style.merge("display:block;outline:none;border:none;text-decoration:none", class_style(assigns))}
      {@rest}
    />
    """
  end

  @doc """
  A horizontal divider.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)

  def hr(assigns) do
    ~H"""
    <hr style={Style.merge("width:100%;border:none;border-top:1px solid #eaeaea", class_style(assigns))} {@rest} />
    """
  end

  @doc """
  A web font, declared inside `<.head>`.

  Renders a `<style>` tag with an `@font-face` rule (plus `mso-font-alt` for
  Outlook) and applies the family to every element.

      <.font
        font_family="Roboto"
        fallback_font_family="Verdana"
        web_font={%{url: "https://fonts.gstatic.com/.../roboto.woff2", format: "woff2"}}
      />
  """
  attr(:font_family, :string, required: true)
  attr(:fallback_font_family, :string, default: "Verdana")
  attr(:web_font, :map, default: nil, doc: "a map with `:url` and `:format` keys")
  attr(:font_weight, :any, default: 400)
  attr(:font_style, :string, default: "normal")

  def font(assigns) do
    src =
      case assigns.web_font do
        %{url: url, format: format} -> "src: url(#{url}) format('#{format}');"
        nil -> ""
      end

    css = """
    @font-face {
      font-family: '#{assigns.font_family}';
      font-style: #{assigns.font_style};
      font-weight: #{assigns.font_weight};
      mso-font-alt: '#{assigns.fallback_font_family}';
      #{src}
    }

    * {
      font-family: '#{assigns.font_family}', #{assigns.fallback_font_family};
    }
    """

    assigns = assign(assigns, :style_tag, Phoenix.HTML.raw(["<style>\n", css, "</style>"]))

    ~H"{@style_tag}"
  end

  @doc """
  A piece of inline code.
  """
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)
  slot(:inner_block, required: true)

  def code_inline(assigns) do
    assigns = put_style(assigns, class_style(assigns))

    ~H"""
    <code {@attrs}>{render_slot(@inner_block)}</code>
    """
  end

  @doc """
  A block of code with inline-styled syntax highlighting.

  Highlighting requires the optional `:makeup` dependency plus a lexer for
  the language (for example `:makeup_elixir`); without them — or for unknown
  languages — the code renders escaped but unstyled.

  The theme is a map from makeup token type to inline CSS, plus a `:base`
  entry for the `<pre>` tag. See `PhoenixEmail.Highlight.default_theme/0`.

      <.code_block language="elixir" code={~S'''
      defmodule Hello do
        def world, do: :ok
      end
      '''} />
  """
  attr(:code, :string, required: true)
  attr(:language, :string, default: nil)
  attr(:theme, :map, default: nil)
  attr(:class, :string, default: nil, doc: "tailwind utilities, see `PhoenixEmail.Tailwind`")
  attr(:style, :string, default: nil)
  attr(:rest, :global)

  def code_block(assigns) do
    theme = assigns.theme || Highlight.default_theme()

    assigns =
      assigns
      |> assign(
        :highlighted,
        Phoenix.HTML.raw(Highlight.highlight(assigns.code, assigns.language, theme))
      )
      |> put_style(Style.merge(Map.get(theme, :base), class_style(assigns)))

    ~H"""
    <pre {@attrs}><code>{@highlighted}</code></pre>
    """
  end

  @doc """
  Markdown rendered as email-safe HTML with inline styles.

  Requires the optional `:earmark_parser` dependency. Override the default
  per-tag styles with the `styles` map (tag name to inline CSS); see
  `PhoenixEmail.Markdown.default_styles/0`.

      <.markdown content={@changelog} styles={%{h1: "color:#5e6ad2"}} />
  """
  attr(:content, :string, required: true)
  attr(:styles, :map, default: %{})
  attr(:container_style, :string, default: nil)
  attr(:rest, :global)

  def markdown(assigns) do
    assigns =
      assigns
      |> assign(
        :content_html,
        Phoenix.HTML.raw(Markdown.to_html(assigns.content, assigns.styles))
      )
      |> put_style(assigns.container_style)

    ~H"""
    <div {@attrs}>{@content_html}</div>
    """
  end

  # Tailwind classes translate to declarations that the explicit style
  # attribute can still override by cascade.
  defp class_style(assigns) do
    Style.merge(Tailwind.style(assigns.class), assigns.style)
  end

  # Merges the style into the :global rest so a nil style is dropped instead
  # of rendering an empty style="" attribute.
  defp put_style(assigns, style) do
    assign(assigns, :attrs, Map.put(assigns.rest, :style, style))
  end

  defp slot_text(inner_block) do
    assigns = %{inner_block: inner_block}

    ~H"{render_slot(@inner_block)}"
    |> Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp margin_style(assigns) do
    [
      {"margin", assigns.m},
      {"margin-left", assigns.mx},
      {"margin-right", assigns.mx},
      {"margin-top", assigns.my},
      {"margin-bottom", assigns.my},
      {"margin-top", assigns.mt},
      {"margin-right", assigns.mr},
      {"margin-bottom", assigns.mb},
      {"margin-left", assigns.ml}
    ]
    |> Enum.reject(fn {_property, value} -> is_nil(value) end)
    |> Enum.map_join(";", fn {property, value} -> "#{property}:#{css_unit(value)}" end)
  end

  defp css_unit(value) when is_number(value), do: "#{value}px"
  defp css_unit(value), do: to_string(value)
end
