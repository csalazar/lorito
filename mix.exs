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
      {:ash, "~> 3.18"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:bcrypt_elixir, "~> 3.0"},
      {:dns, "~> 2.4.0"},
      {:ecto_sql, "~> 3.10"},
      {:hammer, "~> 7.0"},
      {:live_monaco_editor, "~> 0.1"},
      {:jason, "~> 1.2"},
      {:nanoid, "~> 2.1.0"},
      {:picosat_elixir, "~> 0.2"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 4.0"},
      {:phoenix_live_view, "~> 1.0"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, "~> 0.18"},
      {:timex, "~> 3.7"},
      {:remote_ip, "~> 1.0"},
      {:req, "~> 0.5.0"},
      {:sentry, "~> 11.0.2"},
      {:socket, "~> 0.3.13"},
      {:solid, "~> 1.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:git_cli, "~> 0.3.0", only: :dev},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:versioce, "~> 2.0.0", only: :dev},
      {:faker, "~> 0.18", only: :test},
      {:floki, ">= 0.30.0", only: :test},
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
