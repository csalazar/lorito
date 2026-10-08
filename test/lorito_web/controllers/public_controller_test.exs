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

  describe "public workspace lookups" do
    test "stores raw JSON and URL-encoded bodies while preserving parsed params" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "/"))
      path = "/#{project.id}/#{workspace.id}"

      for {content_type, body} <- [
            {"application/json", ~s({"event":"callback"})},
            {"application/x-www-form-urlencoded", "event=callback"}
          ] do
        conn =
          Phoenix.ConnTest.build_conn(:post, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", content_type)
          |> post(path, body)

        assert conn.status == 200
      end

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == 2

      for log <- logs do
        assert log.body in [~s({"event":"callback"}), "event=callback"]
        assert log.params == %{"event" => "callback"}
        assert log.body_encoding == "utf-8"
      end
    end

    test "malformed JSON payloads are served and logged without crashing the request" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      configured_response = generate(response(workspace: workspace, actor: user, route: "/"))
      path = "/#{project.id}/#{workspace.id}"

      payloads = [
        {"application/json", "{"},
        {"application/json", ~s({"unterminated":")},
        {"application/problem+json", <<255, 254, 0>>}
      ]

      for {content_type, body} <- payloads do
        conn =
          Phoenix.ConnTest.build_conn(:post, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", content_type)
          |> post(path, body)

        assert conn.status == 200
        assert response(conn, 200) == configured_response.body
      end

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == length(payloads)

      assert Enum.sort(
               Enum.map(logs, fn log ->
                 assert log.params == %{}

                 case log.body_encoding do
                   "utf-8" -> log.body
                   "base64" -> Base.decode64!(log.body)
                 end
               end)
             ) == Enum.sort(Enum.map(payloads, &elem(&1, 1)))
    end

    test "valid scalar JSON and unusual URL encoding remain loggable" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "/"))
      path = "/#{project.id}/#{workspace.id}"

      for {content_type, body} <- [
            {"application/json", "1"},
            {"application/x-www-form-urlencoded", "a=%"}
          ] do
        conn =
          Phoenix.ConnTest.build_conn(:post, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", content_type)
          |> post(path, body)

        assert conn.status == 200
      end

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert Enum.any?(logs, &(&1.body == "1" and &1.params == %{"_json" => 1}))
      assert Enum.any?(logs, &(&1.body == "a=%" and &1.params == %{"a" => "%"}))
    end

    test "parser errors fall back to raw request logging" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      configured_response = generate(response(workspace: workspace, actor: user, route: "*"))
      path = "/#{project.id}/#{workspace.id}"

      deep_form = "a" <> String.duplicate("[x]", 200) <> "=1"

      malformed_requests = [
        {:post, "application/x-www-form-urlencoded", <<"a=", 255>>},
        {:patch, "application/x-www-form-urlencoded", <<"a=", 255>>},
        {:post, "application/x-www-form-urlencoded", deep_form},
        {:post, "multipart/form-data; boundary=fuzz",
         "--fuzz\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\nvalue"},
        {:post, "multipart/form-data; boundary=fuzz",
         <<"--fuzz\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\n", 255,
           "\r\n--fuzz--\r\n">>}
      ]

      for {method, content_type, body} <- malformed_requests do
        conn =
          Phoenix.ConnTest.build_conn(:get, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", content_type)
          |> dispatch(@endpoint, method, path, body)

        assert conn.status == configured_response.status
      end

      invalid_query_conn =
        Phoenix.ConnTest.build_conn(:get, "http://localhost")
        |> get(path <> "?q=%FF")

      assert invalid_query_conn.status == configured_response.status

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == length(malformed_requests) + 1
      assert Enum.all?(logs, &(&1.params == %{}))

      logged_bodies =
        Enum.map(logs, fn log ->
          case log.body_encoding do
            "utf-8" -> log.body
            "base64" -> Base.decode64!(log.body)
          end
        end)

      for {_method, _content_type, body} <- malformed_requests do
        assert body in logged_bodies
      end

      assert Enum.any?(logs, &(&1.url == path <> "?q=%FF"))
    end

    @tag timeout: 30_000
    test "multipart bodies beyond Plug's parser limit are still logged in full" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      configured_response = generate(response(workspace: workspace, actor: user, route: "/"))
      path = "/#{project.id}/#{workspace.id}"

      body =
        "--fuzz\r\nContent-Disposition: form-data; name=\"x\"\r\n\r\n" <>
          String.duplicate("x", 8_000_001) <> "\r\n--fuzz--\r\n"

      conn =
        Phoenix.ConnTest.build_conn(:post, "http://localhost")
        |> Plug.Conn.put_req_header("content-type", "multipart/form-data; boundary=fuzz")
        |> post(path, body)

      assert conn.status == configured_response.status
      assert [%{body: ^body, params: %{}}] = Ash.read!(Lorito.Logs.HTTP)
    end

    test "unusual but valid HTTP inputs are served and logged" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "*"))
      base_path = "/#{project.id}/#{workspace.id}"

      requests = [
        {:request, "BREW", base_path, ""},
        {:get, nil, base_path <> "/%00", ""},
        {:get, nil, base_path <> "/%ZZ", ""},
        {:get, nil, base_path <> "?x=1&x=2&x[y]=3", ""},
        {:post, nil, base_path, <<0, 255, 254, 65>>}
      ]

      for {kind, method, path, body} <- requests do
        request_method = if kind == :request, do: method, else: kind

        conn =
          Phoenix.ConnTest.build_conn(:get, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", "text/plain")

        conn = dispatch(conn, @endpoint, request_method, path, body)

        assert conn.status == 200
      end

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == length(requests)
      assert Enum.any?(logs, &(&1.method == "BREW"))
      assert Enum.any?(logs, &(&1.url == base_path <> "/%00"))
      assert Enum.any?(logs, &(&1.url == base_path <> "/%ZZ"))

      assert Enum.any?(logs, fn log ->
               log.body_encoding == "base64" and Base.decode64!(log.body) == <<0, 255, 254, 65>>
             end)
    end

    test "stores a multipart body including file bytes" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "/"))

      body =
        "--capture-boundary\r\n" <>
          "Content-Disposition: form-data; name=\"note\"\r\n\r\nhello\r\n" <>
          "--capture-boundary\r\n" <>
          "Content-Disposition: form-data; name=\"file\"; filename=\"probe.txt\"\r\n" <>
          "Content-Type: text/plain\r\n\r\nfile bytes\r\n" <>
          "--capture-boundary--\r\n"

      conn =
        Phoenix.ConnTest.build_conn(:post, "http://localhost")
        |> Plug.Conn.put_req_header(
          "content-type",
          "multipart/form-data; boundary=capture-boundary"
        )
        |> post("/#{project.id}/#{workspace.id}", body)

      assert conn.status == 200
      assert [%{body: ^body} = log] = Ash.read!(Lorito.Logs.HTTP)
      assert log.params["note"] == "hello"
    end

    test "stores a large pass-through body in full" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "/"))
      body = String.duplicate("x", 8_000_001)

      conn =
        Phoenix.ConnTest.build_conn(:post, "http://localhost")
        |> Plug.Conn.put_req_header("content-type", "text/plain")
        |> post("/#{project.id}/#{workspace.id}", body)

      assert conn.status == 200
      assert [%{body: ^body}] = Ash.read!(Lorito.Logs.HTTP)
    end

    test "stores binary pass-through bytes including NUL without loss" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      generate(response(workspace: workspace, actor: user, route: "/"))

      bodies = [<<0>>, <<0, 255, 254, 65>>, :binary.copy(<<0, 255, 254, 65>>, 300_000)]

      for body <- bodies do
        conn =
          Phoenix.ConnTest.build_conn(:post, "http://localhost")
          |> Plug.Conn.put_req_header("content-type", "application/octet-stream")
          |> post("/#{project.id}/#{workspace.id}", body)

        assert conn.status == 200
      end

      assert logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == length(bodies)

      assert Enum.sort(
               Enum.map(logs, fn log ->
                 assert log.body_encoding == "base64"
                 Base.decode64!(log.body)
               end)
             ) == Enum.sort(bodies)
    end

    test "both public paths serve responses without loading historical logs", %{conn: conn} do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user, path: "public-#{project.id}"))
      configured_response = generate(response(workspace: workspace, actor: user, route: "/"))
      historical = generate(http_log(workspace_id: workspace.id, project_id: project.id))

      for identity <- [
            Lorito.Workspaces.get_workspace_for_public_request!(%{
              id: workspace.id,
              project_id: project.id
            }),
            Lorito.Workspaces.get_workspace_by_path_for_public_request!(workspace.path)
          ] do
        assert identity.project_id == project.id
        assert %Ash.NotLoaded{} = identity.logs
        assert %Ash.NotLoaded{} = identity.responses
        assert %Ash.NotLoaded{} = identity.template
      end

      loaded =
        Lorito.Workspaces.get_workspace_for_public_response!(%{
          id: workspace.id,
          project_id: project.id
        })

      assert %Ash.NotLoaded{} = loaded.logs
      assert [%{id: response_id}] = loaded.responses
      assert response_id == configured_response.id

      for path <- [
            "/#{project.id}/#{workspace.id}",
            "/#{workspace.path}"
          ] do
        response = get(conn, path)
        assert response.status == configured_response.status

        assert Phoenix.ConnTest.response(response, configured_response.status) ==
                 configured_response.body
      end

      logs = Ash.read!(Lorito.Logs.HTTP)
      assert length(logs) == 3
      assert Enum.any?(logs, &(&1.id == historical.id))
    end

    test "denied workspace requests do not load response data or create logs", %{conn: conn} do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user, path: "public-#{project.id}"))
      generate(response(workspace: workspace, actor: user, route: "hello"))
      historical = generate(http_log(workspace_id: workspace.id, project_id: project.id))

      rate_key = "project_#{project.id}"

      with_mock Lorito.Workspaces, [:passthrough],
        get_workspace_for_public_response!: fn _ ->
          flunk("loaded responses after rate denial")
        end do
        with_mock LoritoWeb.RateLimit,
          hit: fn key, scale, limit ->
            send(self(), {:rate_limit_hit, key, scale, limit})
            {:deny, limit}
          end do
          for path <- ["/#{project.id}/#{workspace.id}/hello", "/#{workspace.path}"] do
            assert get(conn, path) |> json_response(429) == nil
            assert_received {:rate_limit_hit, ^rate_key, _, 20}
          end
        end

        assert_not_called(Lorito.Workspaces.get_workspace_for_public_response!(:_))
      end

      assert [%{id: log_id}] = Ash.read!(Lorito.Logs.HTTP)
      assert log_id == historical.id
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

    test "host that merely ends with the server host is rejected" do
      conn = Phoenix.ConnTest.build_conn(:get, "http://notlocalhost")
      conn = get(conn, "/some/path")

      assert json_response(conn, 404) == nil
      assert Lorito.Logs.list_logs!(%{scoped_logs: false}) == []
    end
  end
end
