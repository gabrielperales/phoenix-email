defmodule Mix.Tasks.PhoenixEmail.Tailwind do
  @shortdoc "Compiles tailwind classes used in email templates into an inline-style map"

  @moduledoc """
  Scans your sources for Tailwind classes, runs the `tailwindcss` binary,
  and writes the class → inline-style map that `PhoenixEmail.Tailwind` uses
  at render time.

      $ mix phoenix_email.tailwind

  Configuration (`config/config.exs`):

      config :phoenix_email,
        tailwind_content: ["lib/**/*.ex"],
        tailwind_config: "assets/tailwind.config.js",   # optional
        tailwind_map_path: "priv/phoenix_email/tailwind.map",
        tailwind_bin: "/usr/local/bin/tailwindcss"      # optional

  Re-run after adding or changing classes in your templates — wire it into
  your `assets.build` and `test` aliases so it stays fresh.
  """

  use Mix.Task

  alias PhoenixEmail.Tailwind.Compiler

  @impl Mix.Task
  def run(_argv) do
    case Compiler.run() do
      {:ok, map} ->
        Mix.shell().info(
          "phoenix_email: compiled #{map_size(map)} tailwind classes " <>
            "to #{PhoenixEmail.Tailwind.map_path()}"
        )

      {:error, reason} ->
        Mix.raise("phoenix_email: tailwind compilation failed — #{reason}")
    end
  end
end
