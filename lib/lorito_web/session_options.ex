defmodule LoritoWeb.SessionOptions do
  @moduledoc false

  # The session is signed, so its contents can be read but not changed.
  # Keep the same options for Plug.Session and the LiveView socket.
  def for_environment(environment) do
    production? = environment == :prod

    [
      store: :cookie,
      key: if(production?, do: "__Host-lorito_key", else: "_lorito_key"),
      signing_salt: "WrUf8ywY",
      same_site: "Lax",
      path: "/",
      http_only: true,
      secure: production?
    ]
  end
end
