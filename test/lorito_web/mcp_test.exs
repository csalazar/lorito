defmodule LoritoWeb.McpTest do
  use Lorito.DataCase
  import Lorito.Test.Generators
  import Phoenix.ConnTest
  import Plug.Conn
  @endpoint LoritoWeb.Endpoint

  setup do
    user = generate(user())

    key =
      Lorito.Accounts.create_api_key!(%{expires_at: DateTime.add(DateTime.utc_now(), 3600)},
        actor: user
      )

    %{user: user, key: key, token: key.__metadata__.plaintext_api_key}
  end

  defp rpc(token, method, params \\ %{}) do
    conn = build_conn() |> put_req_header("content-type", "application/json")
    conn = if token, do: put_req_header(conn, "authorization", "Bearer " <> token), else: conn

    post(
      conn,
      "/_lorito/mcp",
      Jason.encode!(%{jsonrpc: "2.0", id: 1, method: method, params: params})
    )
  end

  defp call(token, name, args \\ %{}) do
    body =
      rpc(token, "tools/call", %{name: name, arguments: %{input: args}}) |> json_response(200)

    refute body["error"], inspect(body)
    refute body["result"]["isError"], inspect(body)
    [%{"text" => text} | _] = body["result"]["content"]
    Jason.decode!(text)
  end

  test "authentication rejects missing, invalid, expired and revoked keys", %{
    user: user,
    key: key,
    token: token
  } do
    expired =
      Lorito.Accounts.create_api_key!(%{expires_at: DateTime.add(DateTime.utc_now(), -60)},
        actor: user
      )

    assert :ok = Lorito.Accounts.destroy_api_key(key, actor: user)

    for invalid <- [nil, "invalid", token, expired.__metadata__.plaintext_api_key] do
      assert rpc(invalid, "tools/list").status == 401
    end
  end

  test "handshake and router tool allowlist", %{token: token} do
    conn =
      rpc(token, "initialize", %{
        protocolVersion: "2025-03-26",
        capabilities: %{},
        clientInfo: %{name: "test", version: "1"}
      })

    assert json_response(conn, 200)["result"]["protocolVersion"] == "2025-03-26"
    assert [_] = get_resp_header(conn, "mcp-session-id")
    tools = rpc(token, "tools/list") |> json_response(200) |> get_in(["result", "tools"])

    assert Enum.sort(Enum.map(tools, & &1["name"])) ==
             Enum.sort(
               ~w(list_templates list_projects create_project get_project_by_name list_workspaces_by_project create_workspace create_response_for_workspace list_logs delete_log get_settings)
             )

    workspace = Enum.find(tools, &(&1["name"] == "list_workspaces_by_project"))
    assert "project_id" in workspace["inputSchema"]["properties"]["input"]["required"]
  end

  test "get_settings returns stored application data without arguments", %{
    token: token,
    user: user
  } do
    setting = Lorito.Settings.get_settings!()

    data = %{
      "dns_enabled" => false,
      "dns_domain" => "example.test",
      "dns_ipv4_address" => "192.0.2.1",
      "dns_ipv6_address" => "",
      "scoped_mode" => true
    }

    Lorito.Settings.update_settings!(setting, %{data: data}, actor: user)
    assert call(token, "get_settings") == data
    assert Lorito.Settings.get_settings!().data == data

    Lorito.Settings.update_settings!(setting, %{data: %{}}, actor: user)
    assert call(token, "get_settings") == %{}
  end

  test "get_settings requires authentication" do
    assert rpc(nil, "tools/call", %{name: "get_settings", arguments: %{}}).status == 401
  end

  test "create tools propagate the actor and persist nested response data", %{
    user: user,
    token: token
  } do
    project = call(token, "create_project", %{name: "MCP project"})
    assert Ash.get!(Lorito.Projects.Project, project["id"]).user_id == user.id

    workspace =
      call(token, "create_workspace", %{project_id: project["id"], name: "MCP workspace"})

    stored = Ash.get!(Lorito.Workspaces.Workspace, workspace["id"])
    assert stored.user_id == user.id
    assert stored.notifiable == false
    assert stored.path == nil

    response =
      call(token, "create_response_for_workspace", %{
        workspace_id: workspace["id"],
        route: "hello",
        body: "hello",
        headers: [%{name: "x-test", value: "yes"}]
      })

    stored = Ash.get!(Lorito.Responses.Response, response["id"])
    assert stored.user_id == user.id
    assert stored.workspace_id == workspace["id"]
    assert stored.body == "hello"
    assert [%{name: "x-test", value: "yes"}] = stored.headers
    assert Enum.any?(call(token, "list_projects")["results"], &(&1["id"] == project["id"]))
    assert [%{"id" => found_id}] = call(token, "get_project_by_name", %{name: "MCP project"})
    assert found_id == project["id"]
    assert [] == call(token, "get_project_by_name", %{name: "missing"})
    template = generate(template(actor: user))
    assert Enum.any?(call(token, "list_templates")["results"], &(&1["id"] == template.id))
  end

  test "workspace tool scopes results and serializes full URLs", %{user: user, token: token} do
    for subdomain <- [nil, "mcp"] do
      project = generate(project(actor: user, subdomain: subdomain))
      other = generate(project(actor: user))
      generate(workspace(project: other, actor: user))

      workspaces =
        for path <- [nil, "custom-#{project.id}"] do
          generate(workspace(project: project, actor: user, path: path))
        end

      results = call(token, "list_workspaces_by_project", %{project_id: project.id})

      assert Enum.sort(Enum.map(results, & &1["id"])) ==
               Enum.sort(Enum.map(workspaces, & &1.id))

      for workspace <- workspaces do
        path = workspace.path
        result = Enum.find(results, &(&1["id"] == workspace.id))
        base = URI.parse(LoritoWeb.Endpoint.url())
        host = if subdomain, do: subdomain <> "." <> base.host, else: base.host

        expected =
          URI.to_string(%{
            base
            | host: host,
              path: if(path, do: "/" <> path, else: "/#{project.id}/#{workspace.id}")
          })

        assert result["full_url"] == expected
      end
    end
  end

  @tag capture_log: true
  test "tool errors are returned for invalid inputs and ambiguous project names", %{
    token: token,
    user: user
  } do
    generate(project(actor: user, name: "duplicate"))
    generate(project(actor: user, name: "duplicate"))

    for {name, args} <- [
          {"get_project_by_name", %{name: "duplicate"}},
          {"get_project_by_name", %{}},
          {"list_workspaces_by_project", %{}},
          {"create_workspace", %{}},
          {"create_response_for_workspace", %{route: "missing-workspace"}},
          {"list_logs", %{inserted_after: "invalid"}},
          {"delete_log", %{log_id: "invalid"}},
          {"delete_log", %{log_id: Ash.UUID.generate()}},
          {"delete_log", %{}}
        ] do
      body =
        rpc(token, "tools/call", %{name: name, arguments: %{input: args}}) |> json_response(200)

      assert body["error"] || body["result"]["isError"], inspect({name, body})
    end
  end

  test "logs serialize both protocols, accept ISO timestamps and delete through MCP", %{
    token: token
  } do
    http = generate(http_log(headers: [["host", "example.test"]]))
    dns = generate(dns_log())

    logs =
      call(token, "list_logs", %{
        inserted_after: DateTime.to_iso8601(DateTime.add(DateTime.utc_now(), -60))
      })

    assert length(logs) == 2
    http_result = Enum.find(logs, &(&1["id"] == http.id))
    dns_result = Enum.find(logs, &(&1["id"] == dns.id))
    assert http_result["http_details"]["host"] == "example.test"
    assert http_result["http_details"]["method"] == "GET"
    assert dns_result["dns_details"]["host"] == dns.query_name

    for log <- [http, dns] do
      assert call(token, "delete_log", %{log_id: log.id}) == true
      assert {:ok, nil} = Ash.get(Lorito.Logs.Log, log.id, not_found_error?: false)
    end
  end
end
