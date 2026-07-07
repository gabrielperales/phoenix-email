defmodule PhoenixEmail.Tailwind.Compiler do
  @moduledoc """
  Runs the real `tailwindcss` binary over your sources and converts its
  output into the class → inline-declarations map used by
  `PhoenixEmail.Tailwind` at render time.

  Works with Tailwind v3 and v4 binaries — the version is detected and both
  the invocation and the CSS post-processing adapt. Normally invoked through
  `mix phoenix_email.tailwind`.
  """

  require Logger

  @fallback_tailwind_version "4.3.2"

  # Logical properties (v4 output) expanded to physical ones, assuming ltr.
  @logical_properties %{
    "margin-inline" => ~w(margin-left margin-right),
    "margin-block" => ~w(margin-top margin-bottom),
    "margin-inline-start" => ~w(margin-left),
    "margin-inline-end" => ~w(margin-right),
    "padding-inline" => ~w(padding-left padding-right),
    "padding-block" => ~w(padding-top padding-bottom),
    "padding-inline-start" => ~w(padding-left),
    "padding-inline-end" => ~w(padding-right)
  }

  @doc """
  Compiles the map and writes it to `PhoenixEmail.Tailwind.map_path/0`.

  ## Options

    * `:content` - glob patterns to scan (default: the `:tailwind_content`
      config key, or `["lib/**/*.ex"]`)
    * `:config` - a `tailwind.config.js` (v3, or v4 via `@config`) or a CSS
      entry point with your `@theme` (v4) to use instead of the generated
      input (default: the `:tailwind_config` config key)
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
  Parses tailwind's CSS output (v3 or v4) into a class → inline-declarations
  map.

  Email-oriented post-processing:

    * custom properties are resolved from the rule itself, `:root`/universal
      selectors, and `@property` initial values, then dropped; declarations
      with an unresolvable `var()` are discarded
    * `calc()` chains of `*` and `/` over numbers are evaluated
    * `rem` becomes px (x16); `rgb(r g b / a)` and `oklch()` become hex (or
      `rgba()` when translucent); `color-mix(..., transparent)` becomes
      `rgba()`
    * logical properties (`padding-inline`, …) become physical pairs (ltr)
    * at-rule blocks (`@media`, `@supports`) and pseudo-class selectors are
      skipped — variants cannot be inlined

  """
  def parse(css) do
    css = strip_comments(css)
    property_vars = property_initial_values(css)

    rules =
      css
      |> preprocess()
      |> scan_rules()

    global_vars = Map.merge(property_vars, global_vars(rules))

    rules
    |> Enum.flat_map(fn {selector, body} ->
      case class_name(selector) do
        nil -> []
        class -> body |> declarations(global_vars) |> to_entry(class)
      end
    end)
    |> Map.new()
  end

  defp to_entry([], _class), do: []
  defp to_entry(declarations, class), do: [{class, Enum.join(declarations, ";")}]

  defp strip_comments(css), do: String.replace(css, ~r{/\*.*?\*/}s, "")

  # `@property --x { ...; initial-value: v }` blocks feed default values for
  # the custom properties v4 utilities reference (e.g. --tw-border-style).
  defp property_initial_values(css) do
    ~r/@property\s+(--[\w-]+)\s*\{[^{}]*?initial-value:\s*([^;{}]+)/
    |> Regex.scan(css)
    |> Map.new(fn [_, name, value] -> {name, String.trim(value)} end)
  end

  # Unwraps @layer blocks, drops every other at-rule (statement or block)
  # and nested `&...` selector blocks, until the CSS is a flat list of rules.
  defp preprocess(css) do
    next =
      css
      |> process_at_rules()
      |> drop_nested_selectors()

    if next == css, do: next, else: preprocess(next)
  end

  defp process_at_rules(css) do
    case Regex.run(~r/@([\w-]+)[^{;]*([{;])/, css, return: :index) do
      nil ->
        css

      [{rule_start, _}, {name_start, name_length}, {brace_start, 1}] ->
        name = binary_part(css, name_start, name_length)
        before = binary_part(css, 0, rule_start)
        before <> process_at_rule(css, name, brace_start)
    end
  end

  defp process_at_rule(css, name, brace_start) do
    case {binary_part(css, brace_start, 1), name} do
      {";", _name} ->
        rest = binary_part(css, brace_start + 1, byte_size(css) - brace_start - 1)
        process_at_rules(rest)

      {"{", "layer"} ->
        {inner, rest} = split_block(css, brace_start + 1)
        inner <> process_at_rules(rest)

      {"{", _other} ->
        {_inner, rest} = split_block(css, brace_start + 1)
        process_at_rules(rest)
    end
  end

  # Splits at `position` (just past an opening brace) into the block's inner
  # content and the remainder after the matching closing brace.
  defp split_block(css, position), do: split_block(css, position, position, 1)

  defp split_block(css, start, position, 0) do
    inner = binary_part(css, start, position - start - 1)
    rest = binary_part(css, position, byte_size(css) - position)
    {inner, rest}
  end

  defp split_block(css, start, position, depth) do
    if position >= byte_size(css) do
      {binary_part(css, start, byte_size(css) - start), ""}
    else
      case binary_part(css, position, 1) do
        "{" -> split_block(css, start, position + 1, depth + 1)
        "}" -> split_block(css, start, position + 1, depth - 1)
        _ -> split_block(css, start, position + 1, depth)
      end
    end
  end

  defp drop_nested_selectors(css) do
    String.replace(css, ~r/&[^{}]*\{[^{}]*\}/, "")
  end

  defp scan_rules(css) do
    ~r/([^{}]+)\{([^{}]*)\}/
    |> Regex.scan(css)
    |> Enum.map(fn [_, selector, body] -> {String.trim(selector), String.trim(body)} end)
  end

  # Custom properties declared on :root/:host or universal selectors act as
  # global defaults (v4 theme variables, v3 --tw-* defaults).
  defp global_vars(rules) do
    rules
    |> Enum.filter(fn {selector, _body} ->
      String.contains?(selector, ":root") or String.starts_with?(selector, "*")
    end)
    |> Enum.flat_map(fn {_selector, body} -> raw_declarations(body) end)
    |> Enum.filter(fn {property, _value} -> String.starts_with?(property, "--") end)
    |> Map.new()
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

  defp raw_declarations(body) do
    body
    |> String.split(";")
    |> Enum.flat_map(fn declaration ->
      case String.split(declaration, ":", parts: 2) do
        [property, value] ->
          [{String.trim(property), value |> String.replace(~r/\s+/, " ") |> String.trim()}]

        _ ->
          []
      end
    end)
  end

  defp declarations(body, global_vars) do
    parsed = raw_declarations(body)

    local_vars = for {"--" <> _ = name, value} <- parsed, into: %{}, do: {name, value}

    vars = Map.merge(global_vars, local_vars)

    parsed
    |> Enum.reject(fn {property, _} -> String.starts_with?(property, "--") end)
    |> Enum.flat_map(fn {property, value} ->
      case value |> resolve_vars(vars) |> normalize_value() do
        nil -> []
        value -> expand_property(property, value)
      end
    end)
  end

  defp expand_property(property, value) do
    case Map.fetch(@logical_properties, property) do
      {:ok, [start_property, end_property]} ->
        case String.split(value, ~r/\s+/, trim: true) do
          [start_value, end_value] ->
            ["#{start_property}:#{start_value}", "#{end_property}:#{end_value}"]

          _single_or_more ->
            Enum.map([start_property, end_property], &"#{&1}:#{value}")
        end

      {:ok, properties} ->
        Enum.map(properties, &"#{&1}:#{value}")

      :error ->
        ["#{property}:#{value}"]
    end
  end

  # Substitutes var() references (innermost first, so nested defaults like
  # var(--tw-leading, var(--text-sm--line-height)) resolve in passes) until
  # stable. An unresolvable var() without default poisons the declaration.
  defp resolve_vars(value, vars), do: resolve_vars(value, vars, 5)

  defp resolve_vars(value, _vars, 0), do: value

  defp resolve_vars(value, vars, attempts) do
    next = substitute_vars(value, vars)
    if next == value, do: next, else: resolve_vars(next, vars, attempts - 1)
  end

  defp substitute_vars(value, vars) do
    Regex.replace(
      ~r/var\((--[\w-]+)(,\s*((?:[^()]|\([^()]*\))*))?\)/,
      value,
      fn _, name, comma_part, default ->
        cond do
          Map.has_key?(vars, name) -> Map.fetch!(vars, name)
          comma_part != "" -> default
          true -> "__unresolved__"
        end
      end
    )
  end

  defp normalize_value(value) do
    if String.contains?(value, "__unresolved__") or String.contains?(value, "var(") do
      nil
    else
      value
      |> eval_calc()
      |> convert_rem()
      |> convert_oklch()
      |> convert_color_mix()
      |> convert_rgb()
      |> expand_short_hex()
    end
  end

  # #abc -> #aabbcc; some older email clients only understand 6-digit hex.
  defp expand_short_hex(value) do
    Regex.replace(~r/#([0-9a-fA-F]{3})\b/, value, fn _, hex ->
      "#" <> (hex |> String.graphemes() |> Enum.map_join(&(&1 <> &1)) |> String.downcase())
    end)
  end

  # Evaluates calc() chains of * and / over numbers where at most one operand
  # carries a unit: calc(0.25rem * 5) -> 1.25rem, calc(1 / 2 * 100%) -> 50%.
  defp eval_calc(value) do
    Regex.replace(~r/calc\(([^()]*)\)/, value, fn full, expression ->
      evaluate_calc_expression(expression, full)
    end)
  end

  # v4 emits rounded-full as calc(infinity * 1px).
  defp evaluate_calc_expression(expression, full) do
    if String.match?(expression, ~r/^\s*infinity\s*\*\s*1px\s*$/i) do
      "9999px"
    else
      case eval_expression(expression) do
        {:ok, result} -> result
        :error -> full
      end
    end
  end

  defp eval_expression(expression) do
    tokens = Regex.scan(~r/(-?\d*\.?\d+)([a-z%]*)|([*\/])/, expression, capture: :all_but_first)

    with {:ok, first, operations} <- collect_tokens(tokens),
         {:ok, unit} <- single_unit(tokens),
         {:ok, result} <- apply_operations(first, operations) do
      {:ok, format_number(result) <> unit}
    end
  end

  defp collect_tokens([[number, _unit] | rest]) when number != "" do
    with {:ok, operations} <- collect_operations(rest, []) do
      {:ok, parse_number(number), operations}
    end
  end

  defp collect_tokens(_tokens), do: :error

  defp collect_operations([], acc), do: {:ok, Enum.reverse(acc)}

  defp collect_operations([[_, _, operator], [number, _unit] | rest], acc) when number != "" do
    collect_operations(rest, [{operator, parse_number(number)} | acc])
  end

  defp collect_operations(_tokens, _acc), do: :error

  defp single_unit(tokens) do
    tokens
    |> Enum.flat_map(fn
      [number, unit] when number != "" and unit != "" -> [unit]
      _other -> []
    end)
    |> Enum.uniq()
    |> case do
      [] -> {:ok, ""}
      [unit] -> {:ok, unit}
      _many -> :error
    end
  end

  defp apply_operations(first, operations) do
    Enum.reduce_while(operations, {:ok, first}, fn
      {"*", number}, {:ok, acc} -> {:cont, {:ok, acc * number}}
      {"/", number}, {:ok, _acc} when number == 0.0 -> {:halt, :error}
      {"/", number}, {:ok, acc} -> {:cont, {:ok, acc / number}}
    end)
  end

  defp convert_rem(value) do
    Regex.replace(~r/(-?\d*\.?\d+)rem\b/, value, fn _, number ->
      format_number(parse_number(number) * 16) <> "px"
    end)
  end

  # oklch(63.7% 0.237 25.331) -> #fb2c36 (OKLCh -> OKLab -> linear sRGB).
  defp convert_oklch(value) do
    Regex.replace(
      ~r/oklch\(\s*(\d*\.?\d+)(%?)\s+(\d*\.?\d+)\s+(\d*\.?\d+)(?:deg)?\s*(?:\/\s*(\d*\.?\d+)(%?))?\s*\)/,
      value,
      fn _, lightness, percent, chroma, hue, alpha, alpha_percent ->
        lightness = parse_number(lightness)
        lightness = if percent == "%", do: lightness / 100, else: lightness
        {r, g, b} = oklch_to_srgb(lightness, parse_number(chroma), parse_number(hue))

        case normalize_alpha(alpha, alpha_percent) do
          1.0 -> hex(r, g, b)
          alpha -> "rgba(#{r},#{g},#{b},#{format_number(alpha)})"
        end
      end
    )
  end

  defp normalize_alpha("", _percent), do: 1.0
  defp normalize_alpha(alpha, "%"), do: parse_number(alpha) / 100
  defp normalize_alpha(alpha, _percent), do: parse_number(alpha)

  defp oklch_to_srgb(lightness, chroma, hue) do
    radians = hue * :math.pi() / 180
    a = chroma * :math.cos(radians)
    b = chroma * :math.sin(radians)

    l = :math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
    m = :math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
    s = :math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)

    red = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    green = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    blue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

    {srgb_channel(red), srgb_channel(green), srgb_channel(blue)}
  end

  defp srgb_channel(linear) do
    gamma =
      if linear > 0.0031308 do
        1.055 * :math.pow(linear, 1 / 2.4) - 0.055
      else
        12.92 * linear
      end

    gamma |> max(0.0) |> min(1.0) |> Kernel.*(255) |> round()
  end

  # color-mix(in srgb, <color> N%, transparent) -> rgba(color, N/100).
  defp convert_color_mix(value) do
    Regex.replace(
      ~r/color-mix\(in\s+[\w-]+,\s*(#[0-9a-fA-F]{3}\b|#[0-9a-fA-F]{6}\b|rgba?\([^()]*\))\s+(\d*\.?\d+)%\s*,\s*transparent\s*\)/,
      value,
      fn full, color, percent ->
        case color_channels(color) do
          {r, g, b} -> "rgba(#{r},#{g},#{b},#{format_number(parse_number(percent) / 100)})"
          nil -> full
        end
      end
    )
  end

  defp color_channels("#" <> hex) when byte_size(hex) == 3 do
    hex
    |> String.graphemes()
    |> Enum.map(&String.to_integer(&1 <> &1, 16))
    |> List.to_tuple()
  end

  defp color_channels("#" <> hex) when byte_size(hex) == 6 do
    hex
    |> String.to_charlist()
    |> Enum.chunk_every(2)
    |> Enum.map(&List.to_integer(&1, 16))
    |> List.to_tuple()
  end

  defp color_channels("rgb" <> _ = color) do
    case Regex.run(~r/rgba?\(\s*(\d+)[,\s]+(\d+)[,\s]+(\d+)/, color) do
      [_, r, g, b] -> {String.to_integer(r), String.to_integer(g), String.to_integer(b)}
      nil -> nil
    end
  end

  defp color_channels(_color), do: nil

  # rgb(0 0 0 / 1) -> #000000; alpha < 1 -> rgba(0,0,0,0.5) for older clients.
  defp convert_rgb(value) do
    Regex.replace(
      ~r/rgba?\(\s*(\d+)\s+(\d+)\s+(\d+)\s*(?:\/\s*([\d.]+))?\s*\)/,
      value,
      fn _, r, g, b, alpha ->
        case alpha do
          "" -> hex(String.to_integer(r), String.to_integer(g), String.to_integer(b))
          "1" -> hex(String.to_integer(r), String.to_integer(g), String.to_integer(b))
          alpha -> "rgba(#{r},#{g},#{b},#{alpha})"
        end
      end
    )
  end

  defp hex(r, g, b) do
    "#" <>
      Enum.map_join([r, g, b], fn channel ->
        channel
        |> Integer.to_string(16)
        |> String.downcase()
        |> String.pad_leading(2, "0")
      end)
  end

  defp parse_number(number) do
    {value, ""} = number |> normalize_float() |> Float.parse()
    value
  end

  defp normalize_float("." <> _ = number), do: "0" <> number
  defp normalize_float("-." <> rest), do: "-0." <> rest
  defp normalize_float(number), do: number

  defp format_number(number) do
    truncated = trunc(number)

    if number == truncated do
      Integer.to_string(truncated)
    else
      :erlang.float_to_binary(number / 1, [:compact, decimals: 4])
    end
  end

  defp compile_css(content, config) do
    with {:ok, command, prefix_args, input_base} <- resolve_binary(),
         {:ok, major} <- detect_version(command, prefix_args) do
      tmp =
        Path.join(
          input_base || System.tmp_dir!(),
          "phoenix_email_tailwind_#{System.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp)

      try do
        output = Path.join(tmp, "output.css")
        args = build_args(major, tmp, content, config) ++ ["--output", output]

        case System.cmd(command, prefix_args ++ args, stderr_to_stdout: true) do
          {_, 0} -> {:ok, File.read!(output)}
          {out, status} -> {:error, "tailwindcss exited with #{status}: #{out}"}
        end
      after
        File.rm_rf!(tmp)
      end
    end
  end

  defp build_args(3, tmp, content, config) do
    input = Path.join(tmp, "input.css")
    File.write!(input, "@tailwind utilities;\n")
    config_path = config || write_v3_config(tmp, content)
    ["--config", config_path, "--input", input]
  end

  defp build_args(4, tmp, content, config) do
    if config && Path.extname(config) == ".css" do
      ["--input", Path.expand(config)]
    else
      input = Path.join(tmp, "input.css")
      File.write!(input, v4_input(content, config))
      ["--input", input]
    end
  end

  defp write_v3_config(tmp, content) do
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

  defp v4_input(content, config) do
    sources = Enum.map_join(content, "\n", &"@source #{inspect(Path.expand(&1))};")
    legacy_config = if config, do: "@config #{inspect(Path.expand(config))};\n", else: ""

    """
    @layer theme, utilities;
    @import "tailwindcss/theme.css" layer(theme);
    @import "tailwindcss/utilities.css" layer(utilities) source(none);
    #{legacy_config}#{sources}
    """
  end

  defp detect_version(command, prefix_args) do
    case System.cmd(command, prefix_args ++ ["--help"], stderr_to_stdout: true) do
      {out, 0} ->
        case Regex.run(~r/tailwindcss v(\d+)\./, out) do
          [_, major] when major in ~w(3 4) -> {:ok, String.to_integer(major)}
          [_, major] -> {:error, "unsupported tailwindcss major version #{major}"}
          nil -> {:error, "could not detect the tailwindcss version from --help"}
        end

      {out, status} ->
        {:error, "tailwindcss --help exited with #{status}: #{out}"}
    end
  end

  @doc """
  Finds the tailwind binary: `:tailwind_bin` config, the tailwind hex
  package, `tailwindcss` in `$PATH`, or — as a fallback — a Tailwind
  v#{@fallback_tailwind_version} CLI installed with npm into a cached
  directory. New Phoenix projects ship the hex package with v4, so that is
  the path most apps take.

  Returns `{:ok, command, prefix_args, input_base_dir}` — the last element
  forces the generated input CSS to live next to the npm `node_modules` so
  the CLI can resolve its imports (`nil` for standalone binaries).
  """
  def resolve_binary do
    cond do
      bin = Application.get_env(:phoenix_email, :tailwind_bin) ->
        {:ok, bin, [], nil}

      bin = hex_package_bin() ->
        {:ok, bin, [], nil}

      bin = System.find_executable("tailwindcss") ->
        {:ok, bin, [], nil}

      npm = System.find_executable("npm") ->
        npm_cli(npm)

      true ->
        {:error,
         "no tailwindcss binary found — set config :phoenix_email, :tailwind_bin, " <>
           "add the :tailwind hex package, or install tailwindcss/npm"}
    end
  end

  # Installs the v4 CLI once into a cached directory; the npm distribution
  # (unlike the standalone binary) resolves "tailwindcss/*.css" imports
  # through node_modules, which is why the input is generated next to it.
  defp npm_cli(npm) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "phoenix_email_tailwind_cli_#{@fallback_tailwind_version}"
      )

    bin = Path.join([dir, "node_modules", ".bin", "tailwindcss"])

    if File.exists?(bin) do
      {:ok, bin, [], dir}
    else
      File.mkdir_p!(dir)

      install_args = [
        "install",
        "--prefix",
        dir,
        "tailwindcss@#{@fallback_tailwind_version}",
        "@tailwindcss/cli@#{@fallback_tailwind_version}"
      ]

      case System.cmd(npm, install_args, stderr_to_stdout: true) do
        {_, 0} -> {:ok, bin, [], dir}
        {out, status} -> {:error, "npm install of the tailwind CLI failed (#{status}): #{out}"}
      end
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
