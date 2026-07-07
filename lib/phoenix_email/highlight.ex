defmodule PhoenixEmail.Highlight do
  @moduledoc """
  Inline-styled syntax highlighting for `PhoenixEmail.Components.code_block/1`.

  Uses [makeup](https://hex.pm/packages/makeup) when available — add `:makeup`
  plus a lexer such as `:makeup_elixir` to your dependencies. Without makeup
  (or for unknown languages) the code renders escaped but unstyled.

  A theme is a map from makeup token type to an inline CSS string, plus a
  `:base` entry applied to the surrounding `<pre>`. Token types fall back to
  their parent type (`:keyword_declaration` → `:keyword`), so a few entries
  cover a whole language.
  """

  alias Phoenix.HTML.Engine

  @default_theme %{
    base:
      "background:#f6f8fa;border-radius:6px;color:#24292e;" <>
        "font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;" <>
        "font-size:13px;line-height:20px;padding:16px;white-space:pre",
    comment: "color:#6a737d;font-style:italic",
    keyword: "color:#d73a49",
    operator: "color:#d73a49",
    punctuation: "color:#24292e",
    name_attribute: "color:#005cc5",
    name_builtin: "color:#005cc5",
    name_class: "color:#6f42c1",
    name_constant: "color:#005cc5",
    name_decorator: "color:#6f42c1",
    name_function: "color:#6f42c1",
    string: "color:#032f62",
    string_symbol: "color:#005cc5",
    number: "color:#005cc5",
    generic_deleted: "color:#b31d28",
    generic_inserted: "color:#22863a"
  }

  @doc """
  The default theme, GitHub-light-like colors.
  """
  def default_theme, do: @default_theme

  @doc """
  Highlights `code` for `language`, returning HTML-escaped iodata where each
  styled token is wrapped in a `<span style="...">`.
  """
  def highlight(code, language, theme \\ @default_theme)

  def highlight(code, nil, _theme), do: escape(code)

  def highlight(code, language, theme) do
    with true <- Code.ensure_loaded?(Makeup.Registry),
         {:ok, {lexer, opts}} <- Makeup.Registry.fetch_lexer_by_name(language) do
      code
      |> lexer.lex(opts)
      |> Enum.map(&render_token(&1, theme))
    else
      _ -> escape(code)
    end
  end

  defp render_token({type, _meta, value}, theme) do
    escaped = value |> IO.iodata_to_binary() |> escape()

    case token_style(type, theme) do
      nil -> escaped
      style -> [~s(<span style="), style, ~s(">), escaped, "</span>"]
    end
  end

  defp token_style(type, theme) do
    case Map.fetch(theme, type) do
      {:ok, style} ->
        style

      :error ->
        case parent_type(type) do
          nil -> nil
          parent -> token_style(parent, theme)
        end
    end
  end

  # :keyword_declaration -> :keyword, :name_function -> :name, :name -> nil
  defp parent_type(type) do
    case type |> Atom.to_string() |> String.split("_") do
      [_single] ->
        nil

      parts ->
        parts
        |> Enum.drop(-1)
        |> Enum.join("_")
        |> String.to_existing_atom()
    end
  rescue
    ArgumentError -> nil
  end

  defp escape(text) do
    Engine.encode_to_iodata!(text)
  end
end
