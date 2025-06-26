# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :lorito,
  ecto_repos: [Lorito.Repo],
  generators: [binary_id: true]

config :nanoid,
  size: 8,
  alphabet: "_-0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

# Configures the endpoint
config :lorito, LoritoWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: LoritoWeb.ErrorHTML, json: LoritoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Lorito.PubSub,
  live_view: [signing_salt: "lnTIWTAR"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.24.2",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.17",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :versioce,
  changelog: [
    datagrabber: Versioce.Changelog.DataGrabber.Git,
    formatter: Versioce.Changelog.Formatter.Keepachangelog
  ],
  files: [
    "README.md",
    "mix.exs"
  ],
  git: [
    dirty_add: true,
    tag_template: "v{version}",
    tag_message_template: "Release v{version}"
  ],
  post_hooks: [Versioce.PostHooks.Git.Release]

if config_env() in [:dev, :test] do
  import_config ".env.exs"
end

import_config "#{config_env()}.exs"
