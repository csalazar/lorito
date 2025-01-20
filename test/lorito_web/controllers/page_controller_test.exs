defmodule LoritoWeb.PageControllerTest do
  use LoritoWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert conn.status == 404
  end
end
