defmodule LoritoWeb.Plugs.RequireAuthenticatedUser do
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> redirect(to: "/_lorito/sign-in") |> halt()
    end
  end
end
