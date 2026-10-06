defmodule LoritoWeb.SessionOptionsTest do
  use ExUnit.Case, async: true

  alias LoritoWeb.SessionOptions

  test "production session remains secure even behind an HTTP TLS-terminating proxy" do
    opts = SessionOptions.for_environment(:prod)

    conn =
      Plug.Test.conn(:get, "http://example.com/_lorito")
      |> Plug.Conn.put_private(:plug_skip_csrf_protection, true)
      |> Map.put(:secret_key_base, String.duplicate("s", 64))
      |> Plug.Session.call(Plug.Session.init(opts))
      |> Plug.Conn.fetch_session()
      |> Plug.Conn.put_session(:user_id, "user")
      |> Plug.Conn.send_resp(200, "ok")

    [cookie] = Plug.Conn.get_resp_header(conn, "set-cookie")
    assert cookie =~ "__Host-lorito_key="
    assert cookie =~ "; secure"
    assert cookie =~ "; HttpOnly"
    assert cookie =~ "; path=/"
    assert cookie =~ "; SameSite=Lax"
    refute cookie =~ "; domain="
  end

  test "local HTTP development keeps a usable session cookie" do
    opts = SessionOptions.for_environment(:dev)
    assert opts[:key] == "_lorito_key"
    assert opts[:secure] == false
  end
end
