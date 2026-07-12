defmodule Anthropic.MixProject do
  use Mix.Project

  @name "anthropic_community"
  @version "0.5.0"
  @repo_url "https://github.com/tubedude/anthropic-community"

  def project do
    [
      app: :anthropic,
      description:
        "Elixir client for the Anthropic Messages API — typed content blocks, native tool use, streaming, retries.",
      name: @name,
      source_url: @repo_url,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Anthropic.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:finch, "~> 0.18"},
      {:jason, "~> 1.4"},
      {:ex_image_info, "~> 0.2.4"},
      {:telemetry, "~> 1.2"},
      {:nimble_options, "~> 1.1"},
      {:mime, "~> 2.0"},
      {:mox, "~> 1.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  def package do
    [
      name: @name,
      files: ~w(lib mix.exs README.md CHANGELOG.md LICENSE),
      licenses: ["Apache-2.0"],
      maintainers: ["Roberto Trevisan"],
      links: %{
        "GitHub" => @repo_url,
        "Changelog" => "#{@repo_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
