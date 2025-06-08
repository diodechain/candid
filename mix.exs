defmodule Candid.MixProject do
  use Mix.Project

  @url "https://github.com/diodechain/candid"
  def project do
    [
      app: :candid,
      version: "1.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),

      # Hex
      description: "Candid is a binary encoding format for the Internet Computer (ICP).",
      package: [
        licenses: ["Apache-2.0"],
        maintainers: ["Dominic Letz"],
        links: %{"GitHub" => @url}
      ],
      # Docs
      name: "Candid",
      source_url: @url,
      docs: [
        # The main page in the docs
        main: "Candid",
        extras: ["README.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      lint: ["format --check-formatted", "credo --strict", "dialyzer"]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:leb128, "~> 1.0.0"}
    ]
  end
end
