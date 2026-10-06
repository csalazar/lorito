defmodule LoritoWeb.Plugs.RequireHTTPSTest do
  use ExUnit.Case, async: true

  alias LoritoWeb.Plugs.RequireHTTPS

  @ssl_options Plug.SSL.init(
                 rewrite_on: [:x_forwarded_proto],
                 hsts: false,
                 exclude: [conn: {RequireHTTPS, :public_request?, []}]
               )

  test "redirects an HTTP dashboard request without setting HSTS" do
    conn = Plug.Test.conn(:get, "http://example.com/_lorito?tab=logs")
    conn = Plug.SSL.call(conn, @ssl_options)

    assert conn.status == 301
    assert Plug.Conn.get_resp_header(conn, "location") == ["https://example.com/_lorito?tab=logs"]
    assert Plug.Conn.get_resp_header(conn, "strict-transport-security") == []
  end

  test "redirects an HTTP LiveView upgrade before socket dispatch" do
    conn = Plug.Test.conn(:get, "http://example.com/live/websocket")
    conn = Plug.SSL.call(conn, @ssl_options)

    assert conn.status == 301
    assert Plug.Conn.get_resp_header(conn, "location") == ["https://example.com/live/websocket"]
  end

  test "redirects HTTP authentication and MCP writes without changing the method" do
    for path <- ["/_lorito/users/log_in", "/_lorito/mcp"] do
      conn = Plug.Test.conn(:post, "http://example.com#{path}")
      conn = Plug.SSL.call(conn, @ssl_options)

      assert conn.status == 307
      assert Plug.Conn.get_resp_header(conn, "location") == ["https://example.com#{path}"]
    end
  end

  test "accepts HTTPS forwarded by the TLS-terminating proxy" do
    conn =
      Plug.Test.conn(:get, "http://example.com/_lorito")
      |> Plug.Conn.put_req_header("x-forwarded-proto", "https")
      |> Plug.SSL.call(@ssl_options)

    assert conn.scheme == :https
    refute conn.halted
  end

  test "leaves HTTP payload probes alone" do
    for path <- ["/", "/project/workspace", "/live-probe", "/_lorito-probe"] do
      conn = Plug.Test.conn(:get, "http://example.com#{path}")
      assert Plug.SSL.call(conn, @ssl_options) == conn
    end
  end
end
