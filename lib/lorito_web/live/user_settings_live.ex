defmodule LoritoWeb.UserSettingsLive do
  use LoritoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header>
      User preferences
    </.header>

    <div class="divider divider-accent divider-start pt-8">Display</div>

    <.simple_form for={@form} id="user-settings-form" phx-submit="save">
      <.input
        field={@form[:timezone]}
        type="select"
        label="Timezone"
        required
        options={get_timezones_options()}
      >
      </.input>
      <:actions>
        <.button class="btn btn-primary btn-sm" phx-disable-with="Saving...">Save</.button>
      </:actions>
    </.simple_form>

    <div class="divider divider-accent divider-start pt-8 pb-8">API Key</div>

    <div class="flex flex-col gap-4">
      <%= if @plaintext_api_key do %>
        <div role="alert" class="alert alert-warning">
          <p class="font-semibold">Save this key — it won't be shown again.</p>
          <code class="break-all text-sm">{@plaintext_api_key}</code>
        </div>
      <% end %>

      <%= if @api_key do %>
        <div class="flex items-center gap-4">
          <div class="flex-1 flex items-center gap-3">
            <p class="font-mono text-base-content/60 tracking-widest">••••••••••••••••••••</p>
            <p class="text-xs text-base-content/40">
              Expires: {Calendar.strftime(@api_key.expires_at, "%Y-%m-%d")}
            </p>
          </div>
          <.button
            phx-click="create_api_key"
            class="btn btn-primary btn-outline btn-sm"
            data-confirm="This will revoke your existing key. Continue?"
          >
            Regenerate
          </.button>
          <.button
            phx-click="revoke_api_key"
            class="btn btn-secondary btn-outline btn-sm"
            data-confirm="Revoke your API key?"
          >
            Revoke
          </.button>
        </div>
      <% else %>
        <div>
          <.button phx-click="create_api_key" class="btn btn-primary btn-sm">
            Generate API Key
          </.button>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    form = Lorito.Accounts.form_to_update_user(current_user, actor: current_user)

    api_key =
      case Lorito.Accounts.list_api_keys(actor: current_user) do
        {:ok, [key | _]} -> key
        _ -> nil
      end

    {:ok,
     socket
     |> assign(form: to_form(form))
     |> assign(api_key: api_key, plaintext_api_key: nil)}
  end

  def handle_event("save", %{"form" => form_data}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
      {:ok, user} ->
        notify_parent({:saved, user})

        socket =
          socket
          |> put_flash(:info, "User saved successfully")

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, "Could not save user data")
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  def handle_event("create_api_key", _params, socket) do
    current_user = socket.assigns.current_user

    result =
      Lorito.Repo.transaction(fn ->
        with :ok <- revoke_existing_key(socket.assigns.api_key, current_user),
             {:ok, api_key} <-
               Lorito.Accounts.create_api_key(%{expires_at: one_year_from_now()},
                 actor: current_user
               ) do
          api_key
        else
          {:error, error} -> Lorito.Repo.rollback(error)
        end
      end)

    case result do
      {:ok, api_key} ->
        plaintext = api_key.__metadata__.plaintext_api_key

        {:noreply,
         socket
         |> assign(api_key: api_key, plaintext_api_key: plaintext)
         |> put_flash(:info, "API key generated successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not generate API key")}
    end
  end

  def handle_event("revoke_api_key", _params, socket) do
    current_user = socket.assigns.current_user

    case Lorito.Accounts.destroy_api_key(socket.assigns.api_key, actor: current_user) do
      :ok ->
        {:noreply,
         socket
         |> assign(api_key: nil, plaintext_api_key: nil)
         |> put_flash(:info, "API key revoked")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not revoke API key")}
    end
  end

  def get_timezones_options() do
    now = DateTime.utc_now()

    for tz <- Tzdata.canonical_zone_list() do
      offset =
        Timex.Timezone.get(tz, now)
        |> Timex.TimezoneInfo.format_offset()
        |> String.replace_suffix(":00", "")

      {"#{tz} (#{offset})", tz}
    end
  end

  defp revoke_existing_key(nil, _user), do: :ok

  defp revoke_existing_key(key, user) do
    Lorito.Accounts.destroy_api_key(key, actor: user)
  end

  defp one_year_from_now do
    DateTime.utc_now() |> DateTime.add(365, :day)
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
