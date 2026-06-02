defmodule LoritoWeb.PublicControllerTest do
  use ExUnit.Case
  use Lorito.DataCase, async: true

  import Mock
  import Lorito.Test.Generators

  setup do
    conn = Phoenix.ConnTest.build_conn(:get, "http://localhost")
    {:ok, conn: conn}
  end

  @endpoint LoritoWeb.Endpoint
  import Phoenix.ConnTest

  defp put_scoped_mode!(enabled) do
    {:ok, setting} = Lorito.Settings.get_settings()

    Lorito.Settings.update_settings!(setting, %{
      data: Map.merge(setting.data, %{"scoped_mode" => enabled})
    })
  end

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

  describe "catch-all logging with scoped mode" do
    test "unscoped catch-all request logs when scoped mode is disabled", %{conn: conn} do
      put_scoped_mode!(false)

      with_mock LoritoWeb.RateLimit, [:passthrough], hit: fn _, _, _ -> {:allow, 1} end do
        conn = get(conn, "/nonexistent_short_path")
        assert json_response(conn, 404) == nil
      end

      logs = Lorito.Logs.list_logs!(%{scoped_logs: false})
      assert length(logs) == 1

      [log] = logs
      assert is_nil(log.project_id)
      assert is_nil(log.workspace_id)
    end

    test "unscoped catch-all request is not logged when scoped mode is enabled", %{conn: conn} do
      put_scoped_mode!(true)

      with_mock LoritoWeb.RateLimit, [:passthrough], hit: fn _, _, _ -> {:allow, 1} end do
        conn = get(conn, "/nonexistent_short_path")
        assert json_response(conn, 404) == nil
      end

      assert Lorito.Logs.list_logs!(%{scoped_logs: false}) == []
    end

    test "subdomain-scoped catch-all request still logs when scoped mode is enabled" do
      user = generate(user())
      project = generate(project(subdomain: "scopedlogs", actor: user))
      put_scoped_mode!(true)

      conn = Phoenix.ConnTest.build_conn(:get, "http://#{project.subdomain}.localhost")

      with_mock LoritoWeb.RateLimit, [:passthrough], hit: fn _, _, _ -> {:allow, 1} end do
        conn = get(conn, "/nonexistent_short_path")
        assert json_response(conn, 404) == nil
      end

      [log] = Lorito.Logs.list_logs!(%{scoped_logs: true})
      assert log.project_id == project.id
    end
  end

  describe "out of scope" do
    test "request goes to a different host" do
      conn = Phoenix.ConnTest.build_conn(:get, "http://otherdomain.tld")
      conn = get(conn, "/some/path")
      assert json_response(conn, 404) == nil

      assert Lorito.Logs.list_logs!(%{scoped_logs: false}) == []
    end
  end
end
