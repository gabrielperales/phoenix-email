defmodule PhoenixEmail.Style do
  @moduledoc false
  # Helpers to work with inline CSS style strings.

  @doc """
  Merges two CSS style strings, `extra` last so it wins by cascade.

  Returns `nil` when both are blank so the `style` attribute is omitted.
  """
  def merge(base, extra) do
    case {presence(base), presence(extra)} do
      {nil, nil} -> nil
      {base, nil} -> base
      {nil, extra} -> extra
      {base, extra} -> String.trim_trailing(base, ";") <> ";" <> extra
    end
  end

  @doc """
  Parses a style string into a list of `{property, value}` tuples.
  """
  def declarations(nil), do: []

  def declarations(style) do
    style
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

  defp presence(nil), do: nil

  defp presence(string) do
    case String.trim(string) do
      "" -> nil
      trimmed -> trimmed
    end
  end
end
