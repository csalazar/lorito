defmodule LoritoWeb.LogNotificationsTest do
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

  test "new HTTP and DNS logs notify independently of table filters", %{
    conn: conn,
    user: user
  } do
    generate(http_log())
    {:ok, view, _} = live(conn, "/_lorito/logs")
    refute_push_event(view, "log-created", %{})
    assert has_element?(view, "#desktop-notification-listener")
    refute has_element?(view, "#desktop-notifications")

    for {generator, protocol} <- [{http_log(), "HTTP"}, {dns_log(), "DNS"}] do
      log = generate(generator)
      assert_push_event(view, "log-created", %{id: id, title: title, url: url})
      assert id == log.id
      assert title == "New #{protocol} log"
      assert url == "/_lorito/logs/#{log.id}"
    end

    render_click(view, "toggle_scoped_logs_filter", %{"value" => "true"})
    filtered_log = generate(http_log())
    assert_push_event(view, "log-created", %{id: id})
    assert id == filtered_log.id

    project = generate(project(actor: user))
    log = generate(dns_log(project_id: project.id))
    assert_push_event(view, "log-created", %{id: id, body: body})
    assert id == log.id
    assert body == project.name
  end

  test "workspace receives global notifications without inserting unrelated rows", %{
    conn: conn,
    user: user
  } do
    project = generate(project(actor: user))
    workspace = generate(workspace(project: project, actor: user))
    {:ok, view, _} = live(conn, "/_lorito/projects/#{project.id}/workspaces/#{workspace.id}")
    assert has_element?(view, "#desktop-notification-listener")
    refute has_element?(view, "#desktop-notifications")
    unrelated = generate(dns_log())
    assert_push_event(view, "log-created", %{id: unrelated_id})
    assert unrelated_id == unrelated.id
    refute has_element?(view, "#logs-#{unrelated.id}")

    for generator <- [
          http_log(project_id: project.id, workspace_id: workspace.id),
          dns_log(project_id: project.id, workspace_id: workspace.id)
        ] do
      log = generate(generator)
      assert_push_event(view, "log-created", %{id: id})
      assert id == log.id
      refute_push_event(view, "log-created", %{})
      assert has_element?(view, "#logs-#{log.id}")
    end
  end

  test "preferences owns the control and other authenticated pages receive notifications", %{
    conn: conn
  } do
    {:ok, settings, _} = live(conn, "/_lorito/users/settings")
    assert has_element?(settings, "#desktop-notifications")
    assert has_element?(settings, "#desktop-notification-listener")
    log = generate(http_log())
    assert_push_event(settings, "log-created", %{id: id})
    assert id == log.id

    {:ok, projects, _} = live(conn, "/_lorito/projects")
    refute has_element?(projects, "#desktop-notifications")
    refute_push_event(projects, "log-created", %{})
    log = generate(dns_log())
    assert_push_event(projects, "log-created", %{id: id})
    assert id == log.id
  end
end
