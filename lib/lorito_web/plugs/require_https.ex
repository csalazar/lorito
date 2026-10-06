defmodule LoritoWeb.Plugs.RequireHTTPS do
  @moduledoc false

  # Plug.SSL runs before Phoenix dispatches the LiveView socket. All other
  # paths, including payload probes, remain available over HTTP.
  def public_request?(%Plug.Conn{path_info: ["_lorito" | _]}), do: false
  def public_request?(%Plug.Conn{path_info: ["live" | _]}), do: false
  def public_request?(_conn), do: true
end
