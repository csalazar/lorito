defmodule Lorito.MixProject do
  use Mix.Project

  def project do
    [
      app: :lorito,
      version: "0.3.0",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      preferred_cli_env: [
        test: :test
      ],
      consolidate_protocols: Mix.env() != :dev
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
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:ash, "~> 3.18"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:bcrypt_elixir, "~> 3.0"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, "~> 0.18"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
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
      {:sentry, "~> 11.0.2"},
      {:faker, "~> 0.18", only: :test},
      {:mock, "~> 0.3.0", only: :test}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
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
    password = :crypto.strong_rand_bytes(16) |> Base.url_encode64(padding: false) |> String.trim()

    Lorito.Accounts.register_user(%{email: email, password: password}, authorize?: false)
    IO.puts("User #{email} added with password: #{password}")
  end
end
