defmodule NebulexLocalDistributedAdapter.MixProject do
  use Mix.Project

  @nbx_vsn "2.3.2"

  def project do
    [
      app: :nebulex_local_distributed_adapter,
      version: "0.1.0",
      elixir: "~> 1.13",
      aliases: aliases(),
      deps: deps(),

      # Docs
      name: "NebulexLocalDistributedAdapter"
      # docs: docs(),
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
      nebulex_dep(),

      # Docs
      {:ex_doc, "~> 0.28", only: [:dev, :test], runtime: false}
    ]
  end

  defp nebulex_dep do
    if path = System.get_env("NEBULEX_PATH") do
      {:nebulex, "~> #{@nbx_vsn}", path: path}
    else
      {:nebulex, "~> #{@nbx_vsn}"}
    end
  end

  defp aliases do
    [
      "nbx.setup": [
        "cmd rm -rf nebulex",
        "cmd git clone --depth 1 --branch v#{@nbx_vsn} https://github.com/cabol/nebulex"
      ]
    ]
  end
end
