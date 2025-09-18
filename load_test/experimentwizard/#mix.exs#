defmodule Experimentwizard.MixProject do
  use Mix.Project

  def project do
    [
      app: :experimentwizard,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Experimentwizard.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 2.0.0"},
      {:xmlrpc, "~> 1.4.2"},
      {:jason, "~> 1.4.0"},
      {:plug_cowboy, "~> 2.0"},
      {:floki, "~> 0.34.0"},
      {:json, "~> 1.4"},
      {:sweet_xml, "~> 0.7.3"},
      {:libcluster, "~> 3.3.3"},
      {:kino, "~> 0.10.0"},
      {:yaml_elixir, "~> 2.9.0"},
      {:libgraph, "~> 0.16.0"}
    ]
  end
end
