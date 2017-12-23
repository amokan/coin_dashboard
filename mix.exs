defmodule CoinDashboard.Mixfile do
  use Mix.Project

  def project do
    [
      app: :coin_dashboard,
      version: "0.1.1",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {CoinDashboard.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp escript do
    [main_module: CoinDashboard.CLI]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:httpoison, "~> 0.13.0"},
      {:poison, "~> 3.1"},
      {:table_rex, "~> 1.0"},
      {:sparkline, "~> 0.1.0"},
      {:timex, "~> 3.1"},
      {:number, "~> 0.5.4"},
      {:persistent_ets, "~> 0.1.0"},
      {:tzdata, "== 0.1.8", override: true}
    ]
  end
end
