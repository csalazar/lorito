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

  defp create_key(view, name, expiration \\ "1y") do
    render_click(element(view, "#generate-api-key"))

    view
    |> form("#api-key-form", api_key: %{name: name, expiration: expiration})
    |> render_submit()
  end

  test "multiple keys authenticate independently and revoke individually", %{
    conn: conn,
    user: user
  } do
    {:ok, view, _} = live(conn, "/_lorito/users/settings")
    create_key(view, "First")
    assert has_element?(view, "#generate-api-key-modal .alert-warning code")
    refute has_element?(view, "#api-key-form")
    first = plaintext(view)
    render_click(view, "close_api_key_modal")
    refute has_element?(view, "code")
    refute has_element?(view, "#generate-api-key-modal")
    create_key(view, "Second", "never")
    second = plaintext(view)
    keys = Lorito.Accounts.list_api_keys!(actor: user)
    assert length(keys) == 2
    first_key = Enum.find(keys, &(&1.name == "First"))
    second_key = Enum.find(keys, &(&1.name == "Second"))

    for token <- [first, second] do
      assert rpc(token).status == 200
    end

    {:ok, reloaded, html} = live(conn, "/_lorito/users/settings")
    refute html =~ first
    refute html =~ second
    refute has_element?(reloaded, "code")
    assert html =~ "No expiration"

    render_click(element(view, "#api-key-#{first_key.id} button"))
    assert plaintext(view) == second
    assert rpc(first).status == 401
    assert rpc(second).status == 200
    render_click(element(view, "#api-key-#{second_key.id} button"))
    refute has_element?(view, "code")
    assert [] == Lorito.Accounts.list_api_keys!(actor: user)
  end

  test "expiration presets and default", %{conn: conn, user: user} do
    {:ok, view, _} = live(conn, "/_lorito/users/settings")
    refute has_element?(view, "#api-key-form")
    render_click(element(view, "#generate-api-key"))
    assert has_element?(view, "#generate-api-key-modal")
    assert has_element?(view, ~s(option[value="never"][selected]))

    for {option, days} <- [{"1w", 7}, {"1m", 30}, {"1y", 365}, {"never", nil}] do
      before = DateTime.utc_now()
      create_key(view, option, option)
      key = Enum.find(Lorito.Accounts.list_api_keys!(actor: user), &(&1.name == option))

      if days do
        assert_in_delta DateTime.diff(key.expires_at, before), days * 86400, 5
      else
        assert key.expires_at == nil
      end
    end
  end

  test "invalid input and forged revocation leave keys unchanged", %{conn: conn, user: user} do
    other = generate(user())
    foreign = Lorito.Accounts.create_api_key!(%{name: "Foreign"}, actor: other)
    {:ok, view, html} = live(conn, "/_lorito/users/settings")
    refute html =~ "Foreign"

    for params <- [%{name: " ", expiration: "1y"}, %{name: "Bad", expiration: "invalid"}] do
      assert render_submit(view, "create_api_key", %{"api_key" => params}) =~
               "Could not generate API key"
    end

    assert render_click(view, "revoke_api_key", %{"id" => foreign.id}) =~
             "Could not revoke API key"

    assert Ash.get!(Lorito.Accounts.ApiKey, foreign.id, actor: other)
    assert [] == Lorito.Accounts.list_api_keys!(actor: user)
  end

  test "failed creation and revocation preserve existing keys", %{conn: conn, user: user} do
    key = Lorito.Accounts.create_api_key!(%{name: "Existing"}, actor: user)
    {:ok, view, _} = live(conn, "/_lorito/users/settings")

    with_mock Lorito.Accounts, [:passthrough],
      create_api_key: fn _, _ -> {:error, :unavailable} end do
      assert create_key(view, "New") =~ "Could not generate API key"
      refute has_element?(view, "code")
    end

    with_mock Lorito.Accounts, [:passthrough],
      destroy_api_key: fn _, _ -> {:error, :unavailable} end do
      assert render_click(element(view, "#api-key-#{key.id} button")) =~
               "Could not revoke API key"

      assert has_element?(view, "#api-key-#{key.id}")
    end

    assert [stored] = Lorito.Accounts.list_api_keys!(actor: user)
    assert stored.id == key.id
  end

  test "expired keys remain visible with expiration in the user's timezone", %{
    conn: conn,
    user: user
  } do
    Lorito.Accounts.update_user!(user, %{timezone: "America/New_York"}, actor: user)

    key =
      Lorito.Accounts.create_api_key!(%{name: "Old", expires_at: ~U[2020-01-01 02:00:00Z]},
        actor: user
      )

    {:ok, view, html} = live(conn, "/_lorito/users/settings")
    assert html =~ "2019-12-31 21:00 EST"
    assert has_element?(view, "#api-key-#{key.id}", "Expired")
  end

  defp rpc(token) do
    build_conn()
    |> Plug.Conn.put_req_header("authorization", "Bearer " <> token)
    |> post("/_lorito/mcp", %{jsonrpc: "2.0", id: 1, method: "tools/list"})
  end
end
