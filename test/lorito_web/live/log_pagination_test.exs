defmodule LoritoWeb.LogPaginationTest do
  use Lorito.DataCase
  import Lorito.Test.Generators
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  @endpoint LoritoWeb.Endpoint

  setup do
    user = generate(user())
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user)
    user = Ash.Resource.put_metadata(user, :token, token)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{conn: conn, user: user}
  end

  defp ids(view),
    do:
      view
      |> render()
      |> Floki.parse_fragment!()
      |> Floki.find("#logs tr[id]")
      |> Enum.map(fn {_, attrs, _} -> attrs |> Map.new() |> Map.fetch!("id") end)

  test "cursor navigation, historical live updates, latest bounded refresh, and deletion", %{
    conn: conn
  } do
    for _ <- 1..52, do: generate(http_log())
    {:ok, view, _} = live(conn, "/_lorito/logs")
    assert length(ids(view)) == 50
    first_ids = ids(view)
    view |> element("#logs-older") |> render_click()
    assert length(ids(view)) == 2
    historical_ids = ids(view)
    cursor_url = assert_patch(view)
    {:ok, reloaded, _} = live(conn, cursor_url)
    assert ids(reloaded) == historical_ids
    assert MapSet.disjoint?(MapSet.new(first_ids), MapSet.new(historical_ids))
    log = generate(dns_log())
    assert_push_event(view, "log-created", %{id: id})
    assert id == log.id
    assert ids(view) == historical_ids
    assert has_element?(view, "#log-pagination", "New logs available")
    refute has_element?(view, "#logs-latest")
    assert has_element?(view, "button#logs-older[disabled]")
    view |> element("#logs-newer") |> render_click()
    assert length(ids(view)) == 50
    view |> element("#logs-newer") |> render_click()
    assert has_element?(view, "#logs-#{log.id}")
    assert length(ids(view)) == 50
    render_click(view, "delete", %{"id" => log.id})
    refute has_element?(view, "#logs-#{log.id}")
    assert length(ids(view)) == 50
  end

  test "filters reset the cursor, URL state survives reload, and invalid cursors recover", %{
    conn: conn,
    user: user
  } do
    project = generate(project(actor: user))
    scoped = generate(dns_log(project_id: project.id))
    for _ <- 1..51, do: generate(http_log())
    {:ok, view, _} = live(conn, "/_lorito/logs")
    view |> element("#logs-older") |> render_click()
    render_click(view, "toggle_scoped_logs_filter", %{"value" => "true"})
    assert_patch(view, "/_lorito/logs?scoped_logs=true")
    assert ids(view) == ["logs-#{scoped.id}"]
    {:ok, reloaded, _} = live(conn, "/_lorito/logs?scoped_logs=true")
    assert ids(reloaded) == ids(view)
    render_patch(reloaded, "/_lorito/logs?after=invalid")
    assert_patch(reloaded, "/_lorito/logs")
    assert length(ids(reloaded)) == 50
  end

  test "workspace pages are scoped, paginated, and do not preload the logs relationship", %{
    conn: conn,
    user: user
  } do
    project = generate(project(actor: user))
    workspace = generate(workspace(project: project, actor: user))
    unrelated = generate(http_log())
    for _ <- 1..51, do: generate(dns_log(project_id: project.id, workspace_id: workspace.id))
    loaded = Lorito.Workspaces.get_workspace_page!(%{id: workspace.id, project_id: project.id})
    assert %Ash.NotLoaded{} = loaded.logs
    {:ok, view, _} = live(conn, "/_lorito/projects/#{project.id}/workspaces/#{workspace.id}")
    assert length(ids(view)) == 50
    refute has_element?(view, "#logs-#{unrelated.id}")
    view |> element("#logs-older") |> render_click()
    assert length(ids(view)) == 1
    ["logs-" <> id] = ids(view)
    render_click(view, "delete_log", %{"id" => id})
    assert ids(view) == []
    view |> element("#logs-newer") |> render_click()
    assert length(ids(view)) == 50
  end

  test "bulk deletion leaves an empty historical page with a newer link", %{conn: conn} do
    for _ <- 1..51, do: generate(http_log())
    {:ok, view, _} = live(conn, "/_lorito/logs")
    view |> element("#logs-older") |> render_click()
    render_click(view, "delete_catch_all")
    assert ids(view) == []
    assert has_element?(view, "#logs-newer")
    view |> element("#logs-newer") |> render_click()
    assert ids(view) == []
    assert has_element?(view, "button#logs-older[disabled]")
  end

  test "keysets traverse tied timestamps across HTTP and DNS without duplicates" do
    logs = for _ <- 1..3, generator <- [http_log(), dns_log()], do: generate(generator)

    for table <- ["http_logs", "dns_logs"] do
      Ecto.Adapters.SQL.query!(
        Lorito.Repo,
        "UPDATE #{table} SET inserted_at = '2026-01-01 00:00:00'",
        []
      )
    end

    first = Lorito.Logs.page_logs!(%{}, page: [limit: 2])
    second = Ash.page!(first, :next)
    third = Ash.page!(second, :next)
    actual = Enum.map(first.results ++ second.results ++ third.results, & &1.id)
    assert actual == logs |> Enum.map(& &1.id) |> Enum.sort(:desc)
    refute third.more?
    assert Enum.map(Ash.page!(second, :prev).results, & &1.id) == Enum.map(first.results, & &1.id)
  end
end
