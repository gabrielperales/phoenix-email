defmodule PhoenixEmail.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/gabrielperales/phoenix-email"

  def project do
    [
      app: :phoenix_email,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "PhoenixEmail",
      description: "Build emails with HEEx components. A port of react-email for Phoenix.",
      source_url: @source_url,
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix_live_view, "~> 1.0"},
      # Optional integrations
      {:makeup, "~> 1.1", optional: true},
      {:makeup_elixir, "~> 1.0", optional: true},
      {:earmark_parser, "~> 1.4", optional: true},
      {:swoosh, "~> 1.16", optional: true},
      # Dev/test tooling
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "PhoenixEmail",
      source_ref: "v#{@version}",
      extras: ["README.md"]
    ]
  end
end
