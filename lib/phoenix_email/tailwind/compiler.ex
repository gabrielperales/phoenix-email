defmodule PhoenixEmail.Tailwind.Compiler do
  @moduledoc """
  Runs the real `tailwindcss` binary over your sources and converts its
  output into the class → inline-declarations map used by
  `PhoenixEmail.Tailwind` at render time.

  Normally invoked through `mix phoenix_email.tailwind`.
  """

  require Logger

  @tailwind_version "3.4.17"

  @doc """
  Compiles the map and writes it to `PhoenixEmail.Tailwind.map_path/0`.

  ## Options

    * `:content` - glob patterns to scan (default: the `:tailwind_content`
      config key, or `["lib/**/*.ex"]`)
    * `:config` - path to an existing `tailwind.config.js` to use instead of
      the generated one (its `content` setting wins; default: the
      `:tailwind_config` config key)
    * `:output` - where to write the map (default: `map_path/0`)

  Returns `{:ok, map}` or `{:error, reason}`.
  """
  def run(opts \\ []) do
    content =
      opts[:content] || Application.get_env(:phoenix_email, :tailwind_content, ["lib/**/*.ex"])

    config = opts[:config] || Application.get_env(:phoenix_email, :tailwind_config)
    output = opts[:output] || PhoenixEmail.Tailwind.map_path()

    with {:ok, css} <- compile_css(content, config) do
      map = parse(css)
      File.mkdir_p!(Path.dirname(output))
      File.write!(output, :erlang.term_to_binary(map))
      {:ok, map}
    end
  end

  @doc """
  Parses tailwind's CSS output into a class → inline-declarations map.

  Email-oriented post-processing: `--tw-*` custom properties are resolved
  and dropped, `var()` references substituted, `rem` converted to px (x16),
  and `rgb(r g b / a)` colors converted to hex. Rules under at-rules
  (`@media`, `@supports`) and non-class selectors are skipped — variants
  cannot be inlined.
  """
  def parse(css) do
    css
    |> strip_comments()
    |> strip_at_rules()
    |> scan_rules()
    |> Enum.flat_map(fn {selector, body} ->
      case class_name(selector) do
        nil -> []
        class -> declarations(body) |> to_entry(class)
      end
    end)
    |> Map.new()
  end

  defp to_entry([], _class), do: []
  defp to_entry(declarations, class), do: [{class, Enum.join(declarations, ";")}]

  defp strip_comments(css), do: String.replace(css, ~r{/\*.*?\*/}s, "")

  # Removes at-rule blocks (@media, @supports, ...) with balanced braces.
  defp strip_at_rules(css) do
    case :binary.match(css, "@") do
      :nomatch ->
        css

      {start, _} ->
        before = binary_part(css, 0, start)
        rest = binary_part(css, start, byte_size(css) - start)

        case skip_at_rule(rest) do
          {:ok, remaining} -> before <> strip_at_rules(remaining)
          :error -> css
        end
    end
  end

  defp skip_at_rule(rest) do
    case :binary.match(rest, "{") do
      :nomatch ->
        :error

      {open, _} ->
        skip_block(rest, open + 1, 1)
    end
  end

  defp skip_block(rest, position, 0),
    do: {:ok, binary_part(rest, position, byte_size(rest) - position)}

  defp skip_block(rest, position, _depth) when position >= byte_size(rest), do: {:ok, ""}

  defp skip_block(rest, position, depth) do
    case binary_part(rest, position, 1) do
      "{" -> skip_block(rest, position + 1, depth + 1)
      "}" -> skip_block(rest, position + 1, depth - 1)
      _ -> skip_block(rest, position + 1, depth)
    end
  end

  defp scan_rules(css) do
    ~r/([^{}]+)\{([^{}]*)\}/
    |> Regex.scan(css)
    |> Enum.map(fn [_, selector, body] -> {String.trim(selector), String.trim(body)} end)
  end

  # Accepts only simple single-class selectors and unescapes them:
  # ".max-w-\[465px\]" -> "max-w-[465px]". Anything else (pseudo-classes,
  # combinators, element selectors) is skipped.
  defp class_name("." <> selector) do
    unescaped = String.replace(selector, ~r/\\(.)/, "\\1")

    if String.match?(unescaped, ~r/^[^\s.:>+~,]+$/) do
      unescaped
    else
      nil
    end
  end

  defp class_name(_selector), do: nil

  defp declarations(body) do
    parsed =
      body
      |> String.split(";")
      |> Enum.flat_map(fn declaration ->
        case String.split(declaration, ":", parts: 2) do
          [property, value] -> [{String.trim(property), String.trim(value)}]
          _ -> []
        end
      end)

    vars = for {"--tw-" <> _ = name, value} <- parsed, into: %{}, do: {name, value}

    parsed
    |> Enum.reject(fn {property, _} -> String.starts_with?(property, "--") end)
    |> Enum.flat_map(fn {property, value} ->
      case value |> substitute_vars(vars) |> normalize_value() do
        nil -> []
        value -> ["#{property}:#{value}"]
      end
    end)
  end

  # var(--tw-x, default) -> resolved value or the default; var(--tw-x) with
  # no definition poisons the declaration, which is then dropped.
  defp substitute_vars(value, vars) do
    Regex.replace(~r/var\((--[\w-]+)(,\s*([^()]*))?\)/, value, fn _, name, comma_part, default ->
      cond do
        Map.has_key?(vars, name) -> Map.fetch!(vars, name)
        comma_part != "" -> default
        true -> "__unresolved__"
      end
    end)
  end

  defp normalize_value(value) do
    if String.contains?(value, "__unresolved__") do
      nil
    else
      value
      |> convert_rem()
      |> convert_rgb()
    end
  end

  defp convert_rem(value) do
    Regex.replace(~r/(-?\d*\.?\d+)rem\b/, value, fn _, number ->
      {rem_value, ""} = Float.parse(normalize_float(number))
      format_number(rem_value * 16) <> "px"
    end)
  end

  # rgb(0 0 0 / 1) -> #000000; alpha < 1 -> rgba(0,0,0,0.5) for older clients.
  defp convert_rgb(value) do
    Regex.replace(
      ~r/rgba?\(\s*(\d+)\s+(\d+)\s+(\d+)\s*(?:\/\s*([\d.]+))?\s*\)/,
      value,
      fn _, r, g, b, alpha ->
        case alpha do
          "" -> to_hex(r, g, b)
          "1" -> to_hex(r, g, b)
          alpha -> "rgba(#{r},#{g},#{b},#{alpha})"
        end
      end
    )
  end

  defp to_hex(r, g, b) do
    "#" <>
      Enum.map_join([r, g, b], fn channel ->
        channel
        |> String.to_integer()
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(2, "0")
      end)
  end

  defp normalize_float("." <> _ = number), do: "0" <> number
  defp normalize_float("-." <> rest), do: "-0." <> rest
  defp normalize_float(number), do: number

  defp format_number(number) do
    truncated = trunc(number)

    if number == truncated do
      Integer.to_string(truncated)
    else
      :erlang.float_to_binary(number, [:compact, decimals: 4])
    end
  end

  defp compile_css(content, config) do
    with {:ok, command, prefix_args} <- resolve_binary() do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "phoenix_email_tailwind_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp)

      try do
        input = Path.join(tmp, "input.css")
        output = Path.join(tmp, "output.css")
        File.write!(input, "@tailwind utilities;\n")

        config_path = config || write_config(tmp, content)

        args = prefix_args ++ ["--config", config_path, "--input", input, "--output", output]

        case System.cmd(command, args, stderr_to_stdout: true) do
          {_, 0} -> {:ok, File.read!(output)}
          {out, status} -> {:error, "tailwindcss exited with #{status}: #{out}"}
        end
      after
        File.rm_rf!(tmp)
      end
    end
  end

  defp write_config(tmp, content) do
    globs = Enum.map_join(content, ", ", &inspect(Path.expand(&1)))
    config_path = Path.join(tmp, "tailwind.config.js")

    File.write!(config_path, """
    module.exports = {
      content: [#{globs}],
      corePlugins: { preflight: false }
    }
    """)

    config_path
  end

  @doc """
  Finds the tailwind binary: `:tailwind_bin` config, the tailwind hex
  package, `tailwindcss` in `$PATH`, or `npx tailwindcss@#{@tailwind_version}`.
  """
  def resolve_binary do
    cond do
      bin = Application.get_env(:phoenix_email, :tailwind_bin) ->
        {:ok, bin, []}

      bin = hex_package_bin() ->
        {:ok, bin, []}

      bin = System.find_executable("tailwindcss") ->
        {:ok, bin, []}

      npx = System.find_executable("npx") ->
        {:ok, npx, ["--yes", "tailwindcss@#{@tailwind_version}"]}

      true ->
        {:error,
         "no tailwindcss binary found — set config :phoenix_email, :tailwind_bin, " <>
           "add the :tailwind hex package, or install tailwindcss/npx"}
    end
  end

  defp hex_package_bin do
    tailwind_package = tailwind_package()

    with true <- Code.ensure_loaded?(tailwind_package),
         true <- function_exported?(tailwind_package, :bin_path, 0),
         path when is_binary(path) <- tailwind_package.bin_path(),
         true <- File.exists?(path) do
      path
    else
      _ -> nil
    end
  end

  # Resolved at runtime (and overridable in config) so the compiler does
  # not warn when the optional :tailwind package is absent.
  defp tailwind_package do
    Application.get_env(:phoenix_email, :tailwind_package_module, Tailwind)
  end
end
