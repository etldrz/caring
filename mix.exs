defmodule ExperimentManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :experiment_manager,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: [:leex, :yecc] ++ Mix.compilers()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ExperimentManager.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:erlexec, "~> 2.5.0"},
      {:libcluster, "~> 3.5.0"}
    ]
  end
end
