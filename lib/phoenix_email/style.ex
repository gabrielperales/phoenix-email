defmodule PhoenixEmail.Style do
  @moduledoc false
  # Helpers to work with inline CSS style strings.

  # CSS properties whose numeric values are unitless; every other number is
  # rendered in px, mirroring React's style-object behavior.
  @unitless ~w(animation-iteration-count aspect-ratio border-image-outset
    border-image-slice border-image-width column-count columns flex flex-grow
    flex-shrink font-weight grid-area grid-column grid-column-end
    grid-column-start grid-row grid-row-end grid-row-start line-clamp
    line-height opacity order orphans tab-size widows z-index zoom)

  @doc """
  Converts a style given as a map or keyword list into an inline CSS string.

  Property names may be atoms or strings, in snake_case, camelCase, or
  kebab-case (`:font_size`, `"fontSize"`, and `"font-size"` are equivalent).
  Numeric values get a `px` suffix except for unitless properties such as
  `line-height` or `opacity`. Entries with a `nil` or `false` value are
  dropped, which allows conditional declarations.

  Maps are rendered with their properties sorted so output is deterministic;
  use a keyword list (or list of tuples) to control declaration order.

  Strings pass through untouched and blank styles become `nil` so the
  `style` attribute is omitted.
  """
  def to_css(nil), do: nil
  def to_css(style) when is_binary(style), do: style

  def to_css(style) when is_map(style) do
    style
    |> Enum.map(fn {property, value} -> {property_name(property), value} end)
    |> Enum.sort()
    |> to_css()
  end

  def to_css(style) when is_list(style) do
    style
    |> Enum.reject(fn {_property, value} -> value in [nil, false] end)
    |> Enum.map_join(";", fn {property, value} ->
      property = property_name(property)
      "#{property}:#{css_value(property, value)}"
    end)
    |> presence()
  end

  @doc """
  Merges two styles, `extra` last so it wins by cascade.

  Accepts strings, maps, and keyword lists (see `to_css/1`). Returns `nil`
  when both are blank so the `style` attribute is omitted.
  """
  def merge(base, extra) do
    case {presence(to_css(base)), presence(to_css(extra))} do
      {nil, nil} -> nil
      {base, nil} -> base
      {nil, extra} -> extra
      {base, extra} -> String.trim_trailing(base, ";") <> ";" <> extra
    end
  end

  @doc """
  Parses a style (string, map, or keyword list) into a list of
  `{property, value}` tuples.
  """
  def declarations(nil), do: []

  def declarations(style) do
    style
    |> to_css()
    |> Kernel.||("")
    |> String.split(";")
    |> Enum.flat_map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] ->
          [{property |> String.trim() |> String.downcase(), String.trim(value)}]

        _ ->
          []
      end
    end)
  end

  @doc """
  Extracts the padding of a style string as `{top, right, bottom, left}` in px.

  Supports the `padding` shorthand and the `padding-*` longhands. Values in
  `px`, unitless numbers, and `em`/`rem` (x16) are understood; anything else
  counts as 0, mirroring react-email's `parsePadding`.
  """
  def padding(style) do
    style
    |> declarations()
    |> Enum.reduce({0, 0, 0, 0}, fn
      {"padding", value}, _acc -> shorthand(value)
      {"padding-top", value}, {_t, r, b, l} -> {to_px(value), r, b, l}
      {"padding-right", value}, {t, _r, b, l} -> {t, to_px(value), b, l}
      {"padding-bottom", value}, {t, r, _b, l} -> {t, r, to_px(value), l}
      {"padding-left", value}, {t, r, b, _l} -> {t, r, b, to_px(value)}
      _declaration, acc -> acc
    end)
  end

  @doc """
  Converts px to pt (x0.75) formatted without a trailing `.0`, as used by the
  `mso-text-raise` hack.
  """
  def pt(px) do
    value = px * 0.75
    truncated = trunc(value)

    if value == truncated do
      Integer.to_string(truncated)
    else
      :erlang.float_to_binary(value, [:compact, decimals: 4])
    end
  end

  defp shorthand(value) do
    case value |> String.split(~r/\s+/, trim: true) |> Enum.map(&to_px/1) do
      [all] -> {all, all, all, all}
      [v, h] -> {v, h, v, h}
      [t, h, b] -> {t, h, b, h}
      [t, r, b, l | _] -> {t, r, b, l}
      [] -> {0, 0, 0, 0}
    end
  end

  defp to_px(value) do
    value = String.trim(value)

    cond do
      match = Regex.run(~r/^(-?\d+(?:\.\d+)?)(?:px)?$/, value) ->
        match |> Enum.at(1) |> parse_number() |> round()

      match = Regex.run(~r/^(-?\d+(?:\.\d+)?)(?:em|rem)$/, value) ->
        round(parse_number(Enum.at(match, 1)) * 16)

      true ->
        0
    end
  end

  defp parse_number(string) do
    {number, _rest} = Float.parse(string)
    number
  end

  defp property_name(property) when is_atom(property), do: property_name(Atom.to_string(property))

  defp property_name(property) when is_binary(property) do
    property
    |> String.replace(~r/([a-z\d])([A-Z])/, "\\1-\\2")
    |> String.replace("_", "-")
    |> String.downcase()
  end

  defp css_value(property, value) when is_number(value) do
    if property in @unitless or String.starts_with?(property, "--") do
      to_string(value)
    else
      "#{value}px"
    end
  end

  defp css_value(_property, value), do: to_string(value)

  defp presence(nil), do: nil

  defp presence(string) do
    case String.trim(string) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
