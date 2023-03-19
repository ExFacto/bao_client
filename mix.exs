defmodule BaoClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :bao_client,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bitcoinex, github: "SachinMeier/bitcoinex", branch: "master"},
      {:jason, "~> 1.2"},
      {:req, "~> 0.3.6"}

      # {:finch, "~> 0.15"}
    ]
  end
end
