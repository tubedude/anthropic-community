defmodule Anthropic.MixProject do
  use Mix.Project

  @name "anthropic_community"
  @version "0.3.0"
  @repo_url "https://github.com/tubedude/anthropic-community"

  def project do
    [
      app: :anthropic,
      description: "Unofficial Anthropic API wrapper.",
      name: @name,
      source_url: @repo_url,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
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
      {:finch, "~> 0.13"},
      {:jason, "~> 1.0"},
      {:ex_image_info, "~> 0.2.4"},
      {:telemetry, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  def package do
    [
      name: @name,
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @repo_url}
    ]
  end
end
