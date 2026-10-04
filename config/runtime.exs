import Config

dns_port =
  case Integer.parse(System.get_env("DNS_PORT", "53")) do
    {port, ""} when port in 1..65_535 -> port
    _ -> raise ArgumentError, "DNS_PORT must be an integer between 1 and 65535"
  end

config :lorito, :dns_port, dns_port

if data_dir = System.get_env("TZDATA_DIR") do
  config :tzdata, :data_dir, data_dir
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/lorito start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :lorito, LoritoWeb.Endpoint, server: true
end

if config_env() == :prod do
  database_url = System.fetch_env!("DATABASE_URL")

  database_query = URI.parse(database_url).query || ""

  if Enum.any?(URI.query_decoder(database_query), fn
       {"ssl", "true"} -> false
       {"ssl", _} -> true
       {"ssl_opts", _} -> true
       _ -> false
     end) do
    raise ArgumentError, "DATABASE_URL must not override database TLS options"
  end

  database_ssl_options =
    case {System.get_env("DATABASE_SSL_VERIFY"), System.get_env("DATABASE_SSL_CA_FILE")} do
      {verify, nil} when verify in [nil, "true"] ->
        true

      {"false", nil} ->
        [verify: :verify_none]

      {"false", _} ->
        raise ArgumentError, "DATABASE_SSL_CA_FILE cannot be used when verification is disabled"

      {verify, ca_file} when verify in [nil, "true"] ->
        if String.trim(ca_file) == "" do
          raise ArgumentError, "DATABASE_SSL_CA_FILE must not be empty"
        end

        [cacertfile: ca_file]

      _ ->
        raise ArgumentError, "DATABASE_SSL_VERIFY must be true or false"
    end

  config :lorito, Lorito.Repo,
    start_apps_before_migration: [:ssl],
    url: database_url,
    ssl: database_ssl_options,
    pool_size: 10,
    queue_target: 10_000

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :lorito, LoritoWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    secret_key_base: secret_key_base

  with {:ok, dsn} <- System.fetch_env("SENTRY_DSN") do
    IO.puts("Enabling Sentry reporting ..")

    config :sentry,
      dsn: dsn,
      environment_name: :prod,
      enable_source_code_context: true,
      root_source_code_paths: [File.cwd!()]
  else
    :error -> IO.puts("Sentry DSN not set, skipping Sentry configuration")
  end

  config :lorito, token_signing_secret: secret_key_base
end

config :lorito, :environment, config_env()
