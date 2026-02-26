import Config
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
config :lorito, Lorito.Repo,
  database: "app",
  username: "postgres",
  password: "postgres",
  hostname: "db"

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
secret_key_base = System.fetch_env!("SECRET_KEY_BASE")

config :lorito, LoritoWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: secret_key_base,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
  ]

config :lorito, LoritoWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/lorito_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Enable dev routes for dashboard and mailbox
config :lorito, dev_routes: true, token_signing_secret: secret_key_base

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

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
