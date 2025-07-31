defmodule Lorito.MixProject do
  use Mix.Project

  def project do
    [
      app: :lorito,
      version: "0.2.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        test: :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Lorito.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.7.7"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.18"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3.0", runtime: Mix.env() == :dev},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:nanoid, "~> 2.1.0"},
      {:timex, "~> 3.7"},
      {:hammer, "~> 7.0"},
      {:solid, "~> 1.0"},
      {:live_monaco_editor, "~> 0.1"},
      {:tesla, "~> 1.11"},
      {:safeurl, "~> 1.0"},
      {:remote_ip, "~> 1.0"},
      {:versioce, "~> 2.0.0", only: :dev},
      {:git_cli, "~> 0.3.0", only: :dev},
      {:sentry, "~> 11.0.2"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"],
      add_user: &add_user/1
    ]
  end

  defp add_user(_) do
    Mix.Task.run("app.start")
    shell = Mix.shell()

    email = shell.prompt("email: ") |> String.trim()

    {:ok, password} = Lorito.Accounts.add_user_from_cli(email)
    IO.puts("User #{email} added with password: #{password}")
  end
end
