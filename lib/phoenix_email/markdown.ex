defmodule PhoenixEmail.Markdown do
  @moduledoc """
  Markdown to email-safe HTML for `PhoenixEmail.Components.markdown/1`.

  Requires [earmark_parser](https://hex.pm/packages/earmark_parser) — add
  `:earmark_parser` to your dependencies. Every supported element gets an
  inline style so the result survives email clients; pass custom styles to
  override the defaults per tag.
  """

  alias Phoenix.HTML.Engine

  @default_styles %{
    "h1" => "font-size:32px;font-weight:700;line-height:40px;margin:24px 0 12px",
    "h2" => "font-size:24px;font-weight:700;line-height:32px;margin:24px 0 12px",
    "h3" => "font-size:20px;font-weight:700;line-height:28px;margin:24px 0 12px",
    "h4" => "font-size:18px;font-weight:700;line-height:26px;margin:24px 0 12px",
    "h5" => "font-size:16px;font-weight:700;line-height:24px;margin:24px 0 12px",
    "h6" => "font-size:14px;font-weight:700;line-height:22px;margin:24px 0 12px",
    "p" => "font-size:14px;line-height:24px;margin:16px 0",
    "a" => "color:#067df7;text-decoration:none",
    "blockquote" => "border-left:4px solid #eaeaea;color:#666666;margin:16px 0;padding-left:16px",
    "ul" => "margin:16px 0;padding-left:26px",
    "ol" => "margin:16px 0;padding-left:26px",
    "li" => "font-size:14px;line-height:24px;margin:4px 0",
    "code" =>
      "background-color:#f4f4f4;border-radius:4px;" <>
        "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;" <>
        "font-size:13px;padding:2px 4px",
    "pre" =>
      "background:#f6f8fa;border-radius:6px;color:#24292e;" <>
        "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;" <>
        "font-size:13px;line-height:20px;margin:16px 0;padding:16px;white-space:pre",
    "hr" => "width:100%;border:none;border-top:1px solid #eaeaea;margin:16px 0",
    "img" => "display:block;max-width:100%;margin:16px 0"
  }

  @void_elements ~w(br hr img)

  @doc """
  The default per-tag inline styles.
  """
  def default_styles, do: @default_styles

  @doc """
  Converts a markdown string into email-safe HTML iodata.

  `custom_styles` is a map from tag name (atom or string) to an inline CSS
  string, merged over `default_styles/0`.
  """
  def to_html(markdown, custom_styles \\ %{}) do
    unless Code.ensure_loaded?(EarmarkParser) do
      raise """
      the markdown component requires the :earmark_parser package.

      Add it to your dependencies:

          {:earmark_parser, "~> 1.4"}
      """
    end

    styles = Map.merge(@default_styles, normalize_styles(custom_styles))

    case EarmarkParser.as_ast(markdown) do
      {:ok, ast, _messages} -> render_nodes(ast, styles, nil)
      {:error, ast, _messages} -> render_nodes(ast, styles, nil)
    end
  end

  defp normalize_styles(styles) do
    Map.new(styles, fn {tag, style} -> {to_string(tag), style} end)
  end

  defp render_nodes(nodes, styles, parent) do
    Enum.map(nodes, &render_node(&1, styles, parent))
  end

  defp render_node(text, _styles, _parent) when is_binary(text), do: escape(text)

  # Code inside a fenced block keeps only the pre styling.
  defp render_node({"code", attrs, children, _meta}, styles, "pre") do
    element("code", attrs, nil, render_nodes(children, styles, "code"))
  end

  defp render_node({tag, attrs, children, _meta}, styles, _parent) when is_binary(tag) do
    style = Map.get(styles, tag)

    if tag in @void_elements do
      void_element(tag, attrs, style)
    else
      element(tag, attrs, style, render_nodes(children, styles, tag))
    end
  end

  # Comments and other non-element nodes are dropped.
  defp render_node(_node, _styles, _parent), do: []

  defp element(tag, attrs, style, content) do
    ["<", tag, render_attrs(attrs, style), ">", content, "</", tag, ">"]
  end

  defp void_element(tag, attrs, style) do
    ["<", tag, render_attrs(attrs, style), "/>"]
  end

  defp render_attrs(attrs, style) do
    attrs
    |> merge_style(style)
    |> Enum.map(fn {name, value} -> [" ", name, ~s(="), escape(value), ~s(")] end)
  end

  defp merge_style(attrs, nil), do: attrs

  defp merge_style(attrs, style) do
    case List.keyfind(attrs, "style", 0) do
      nil ->
        attrs ++ [{"style", style}]

      {"style", existing} ->
        List.keyreplace(attrs, "style", 0, {"style", style <> ";" <> existing})
    end
  end

  defp escape(text) do
    Engine.encode_to_iodata!(text)
  end
end
