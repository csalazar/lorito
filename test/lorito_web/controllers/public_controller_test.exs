defmodule LoritoWeb.PublicControllerTest do
  use ExUnit.Case
  use Lorito.DataCase, async: true

  import Lorito.Test.Generators

  setup do
    conn = Phoenix.ConnTest.build_conn()
    {:ok, conn: conn}
  end

  @endpoint LoritoWeb.Endpoint
  import Phoenix.ConnTest

  describe "catch-all and workspace routes" do
    test "returns 404 for unknown path", %{conn: conn} do
      paths = [
        "/nonexistent_short_path",
        "/nonexistent_ws/nonexistent_prj",
        "/nonexistent_ws/nonexistent_prj/nonexistent_route",
        "/this/path/does/not/exist"
      ]

      for path <- paths do
        conn = get(conn, path)
        assert json_response(conn, 404) == nil
      end
    end

    test "returns workspace response for matching route", %{conn: conn} do
      user = generate(user())
      project = generate(project(actor: user))

      workspace = generate(workspace(project: project, actor: user))
      response = generate(response(workspace: workspace, actor: user))

      path = "/#{project.id}/#{workspace.id}/#{response.route}"
      conn = get(conn, path)

      assert conn.status == response.status
      assert response(conn, response.status) == response.body
    end
  end
end
