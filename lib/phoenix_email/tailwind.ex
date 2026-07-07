defmodule PhoenixEmail.Tailwind do
  @moduledoc """
  Tailwind utility classes compiled to inline styles at build time.

  Every visual component accepts a `class` attribute. Unlike react-email's
  `<Tailwind>` wrapper — which runs the Tailwind compiler on every render —
  the compilation happens once, at build time:

  1. `mix phoenix_email.tailwind` scans your source files (like Tailwind's
     own content scanning), runs the real `tailwindcss` binary, and converts
     the resulting CSS into a class → inline-declarations map, stored under
     `priv/`.
  2. At render time each `class` is a plain map lookup, translated into the
     `style` attribute. No external processes, no CSS parsing per email.

  Because the real compiler runs, your `tailwind.config.js` theme, custom
  colors, and arbitrary values (`max-w-[465px]`) all work. The output is
  post-processed for email: `rem` becomes `px` and `rgb()` colors become hex.

  ## Setup

  Add to your `config/config.exs`:

      config :phoenix_email,
        tailwind_content: ["lib/**/*.ex"],
        tailwind_map_path: "priv/phoenix_email/tailwind.map"

  and run `mix phoenix_email.tailwind` after changing classes in your
  templates (wire it into your `assets.build`/`test` aliases). The binary is
  found through, in order: the `:tailwind_bin` config key, the
  [tailwind](https://hex.pm/packages/tailwind) hex package, `tailwindcss` in
  `$PATH`, or `npx tailwindcss@3`.

  ## Limitations

  Classes must appear as literal strings in the scanned sources — same rule
  as Tailwind itself: don't build class names dynamically. Variants (`sm:`,
  `hover:`, `dark:`) are skipped: they cannot be inlined and most email
  clients ignore them. Unknown classes log a warning and are dropped.
  """

  require Logger

  @map_key {__MODULE__, :map}

  @doc """
  Converts a class string into an inline CSS string using the compiled map.

  Returns `nil` for `nil`, empty, or fully unknown input.
  """
  def style(nil), do: nil

  def style(class_string) do
    map = compiled_map()

    class_string
    |> String.split(~r/\s+/, trim: true)
    |> Enum.flat_map(fn class ->
      case Map.fetch(map, class) do
        {:ok, declarations} ->
          [declarations]

        :error ->
          Logger.warning(
            "phoenix_email: class #{inspect(class)} not in the compiled tailwind map, " <>
              "skipping — run `mix phoenix_email.tailwind` after adding classes"
          )

          []
      end
    end)
    |> case do
      [] -> nil
      declarations -> Enum.join(declarations, ";")
    end
  end

  @doc """
  The compiled class map, loaded from `map_path/0` on first use and cached.
  """
  def compiled_map do
    case :persistent_term.get(@map_key, :unset) do
      :unset -> reload!()
      map -> map
    end
  end

  @doc """
  Reloads the compiled map from disk (after re-running the mix task).
  """
  def reload! do
    path = map_path()

    map =
      if File.exists?(path) do
        path |> File.read!() |> :erlang.binary_to_term()
      else
        Logger.warning(
          "phoenix_email: no compiled tailwind map at #{path} — " <>
            "run `mix phoenix_email.tailwind` (class attributes render nothing until then)"
        )

        %{}
      end

    put_map(map)
    map
  end

  @doc """
  Replaces the in-memory map. Useful in tests to avoid touching the disk.
  """
  def put_map(map) when is_map(map) do
    :persistent_term.put(@map_key, map)
    :ok
  end

  @doc """
  Where the compiled map lives. Override with the `:tailwind_map_path`
  config key (use an absolute path in releases).
  """
  def map_path do
    Application.get_env(
      :phoenix_email,
      :tailwind_map_path,
      Path.join(["priv", "phoenix_email", "tailwind.map"])
    )
  end
end
