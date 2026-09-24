defmodule LoritoWeb.UserSettingsLiveTest do
  use Lorito.DataCase
  import Lorito.Test.Generators
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Mock
  @endpoint LoritoWeb.Endpoint

  setup do
    user = generate(user())
    {:ok, token, _} = AshAuthentication.Jwt.token_for_user(user)
    user = Ash.Resource.put_metadata(user, :token, token)

    conn =
      build_conn()
      |> Plug.Test.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{user: user, conn: conn}
  end

  defp plaintext(view) do
    view |> element("code") |> render() |> Floki.parse_fragment!() |> Floki.text()
  end

  test "generate, reload, regenerate and revoke", %{conn: conn, user: user} do
    {:ok, view, html} = live(conn, "/_lorito/users/settings")
    assert html =~ "Generate API Key"
    render_click(element(view, "button[phx-click=create_api_key]"))
    first = plaintext(view)
    assert String.starts_with?(first, "lorito")
    [key] = Lorito.Accounts.list_api_keys!(actor: user)
    assert DateTime.diff(key.expires_at, DateTime.utc_now(), :day) in [364, 365]

    {:ok, reloaded, html} = live(conn, "/_lorito/users/settings")
    refute html =~ first
    refute has_element?(reloaded, "code")
    render_click(element(reloaded, "button[phx-click=create_api_key]"))
    second = plaintext(reloaded)
    refute second == first
    [replacement] = Lorito.Accounts.list_api_keys!(actor: user)
    refute replacement.id == key.id

    for {token, status} <- [{first, 401}, {second, 200}] do
      response =
        build_conn()
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
        |> post("/_lorito/mcp", %{jsonrpc: "2.0", id: 1, method: "tools/list"})

      assert response.status == status
    end

    html = render_click(element(reloaded, "button[phx-click=revoke_api_key]"))
    assert html =~ "Generate API Key"
    refute html =~ second
    assert [] = Lorito.Accounts.list_api_keys!(actor: user)
  end

  test "failed creation displays an error", %{conn: conn} do
    {:ok, view, _} = live(conn, "/_lorito/users/settings")

    with_mock Lorito.Accounts, [:passthrough],
      create_api_key: fn _, _ -> {:error, :unavailable} end do
      html = render_click(element(view, "button[phx-click=create_api_key]"))
      assert html =~ "Could not generate API key"
      refute has_element?(view, "code")
    end
  end

  test "failed replacement creation rolls back revocation", %{conn: conn, user: user} do
    key =
      Lorito.Accounts.create_api_key!(%{expires_at: DateTime.add(DateTime.utc_now(), 3600)},
        actor: user
      )

    {:ok, view, _} = live(conn, "/_lorito/users/settings")

    with_mock Lorito.Accounts, [:passthrough],
      create_api_key: fn _, _ -> {:error, :unavailable} end do
      assert render_click(element(view, "button[phx-click=create_api_key]")) =~
               "Could not generate API key"

      assert Enum.map(Lorito.Accounts.list_api_keys!(actor: user), & &1.id) == [key.id]
      refute has_element?(view, "code")
    end
  end

  test "failed revocation keeps the existing key and aborts regeneration", %{
    conn: conn,
    user: user
  } do
    key =
      Lorito.Accounts.create_api_key!(%{expires_at: DateTime.add(DateTime.utc_now(), 3600)},
        actor: user
      )

    {:ok, view, _} = live(conn, "/_lorito/users/settings")

    with_mock Lorito.Accounts, [:passthrough],
      destroy_api_key: fn _, _ -> {:error, :unavailable} end do
      assert render_click(element(view, "button[phx-click=revoke_api_key]")) =~
               "Could not revoke API key"

      assert render_click(element(view, "button[phx-click=create_api_key]")) =~
               "Could not generate API key"

      assert_not_called(Lorito.Accounts.create_api_key(:_, :_))
      assert Enum.map(Lorito.Accounts.list_api_keys!(actor: user), & &1.id) == [key.id]
      refute has_element?(view, "code")
    end
  end
end
