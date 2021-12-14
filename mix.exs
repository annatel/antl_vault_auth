defmodule AntlVaultAuth.MixProject do
  use Mix.Project

  @source_url "https://github.com/annatel/antl_vault_auth.git"
  @version "0.1.0"

  def project do
    [
      app: :antl_vault_auth,
      version: version(),
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description(),
      docs: docs()
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
      {:libvault, "~> 0.2.0"},
      {:tesla, "~> 1.3", optional: true},
      {:jason, ">= 1.0.0"},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp version(), do: @version

  defp description() do
    "Vault authentication lib with auth token caching"
  end

  defp package() do
    [
      # licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      extras: [
        "README.md"
      ]
    ]
  end

end
