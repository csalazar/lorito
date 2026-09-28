defmodule LoritoWeb.UserSettingsLive do
  use LoritoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header>
      User preferences
    </.header>

    <div class="divider divider-accent divider-start pt-8">
      <h2 class="font-semibold">Display</h2>
    </div>

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

    <div class="divider divider-accent divider-start pt-8">
      <h2 class="font-semibold">Desktop notifications</h2>
    </div>
    <div class="pt-8">
      <p class="text-sm">
        Notify for all new logs while lorito is open in the background.
      </p>
      <div
        id="desktop-notifications"
        phx-hook="DesktopNotifications"
        phx-update="ignore"
        class="flex flex-col items-start gap-4 pt-4"
      >
        <button type="button" class="btn btn-primary btn-sm" aria-pressed="false" data-toggle>
          Enable desktop notifications
        </button>
      </div>
    </div>

    <div class="divider divider-accent divider-start pt-8">
      <h2 class="font-semibold">API keys</h2>
    </div>
    <div class="flex items-center justify-end gap-4 pt-8 pb-4">
      <.button id="generate-api-key" phx-click="open_api_key_modal" class="btn btn-primary btn-sm">
        Generate API key
      </.button>
    </div>

    <div class="flex flex-col gap-4">
      <p :if={@api_keys == []}>No API keys yet.</p>
      <div :for={key <- @api_keys} id={"api-key-#{key.id}"} class="flex flex-wrap items-center gap-4">
        <div class="flex-1">
          <p class="font-semibold">{key.name}</p>
          <p class="text-sm">
            {expiration_label(key.expires_at, @current_user.timezone)}
          </p>
          <p class="text-sm">{if expired?(key.expires_at), do: "Expired", else: "Active"}</p>
        </div>
        <.button
          phx-click="revoke_api_key"
          phx-value-id={key.id}
          class="btn btn-secondary btn-outline btn-sm"
          data-confirm={"Revoke API key “#{key.name}”?"}
        >
          Revoke
        </.button>
      </div>
    </div>
    <.modal
      :if={@show_api_key_modal}
      id="generate-api-key-modal"
      show
      on_cancel={JS.push("close_api_key_modal")}
    >
      <.header>{if @plaintext_api_key, do: "API key generated", else: "Generate API key"}</.header>
      <div
        :if={@plaintext_api_key}
        role="alert"
        class="alert alert-warning mt-4 flex min-w-0 flex-col items-stretch text-left"
      >
        <p class="font-semibold whitespace-normal">Save this key — it won't be shown again.</p>
        <code class="block w-full overflow-x-auto whitespace-nowrap text-sm">{@plaintext_api_key}</code>
      </div>

      <.button
        :if={@plaintext_api_key}
        type="button"
        phx-click={JS.exec("data-cancel", to: "#generate-api-key-modal")}
        class="btn btn-primary btn-sm mt-4"
      >
        Done
      </.button>
      <p :if={@api_key_error} role="alert" class="text-error mt-4">{@api_key_error}</p>
      <.simple_form
        :if={!@plaintext_api_key}
        for={@api_key_form}
        id="api-key-form"
        phx-submit="create_api_key"
      >
        <.input field={@api_key_form[:name]} label="Name" required maxlength="100" />
        <.input
          field={@api_key_form[:expiration]}
          type="select"
          label="Expiration"
          options={[
            {"1 week (7 days)", "1w"},
            {"1 month (30 days)", "1m"},
            {"1 year (365 days)", "1y"},
            {"No expiration", "never"}
          ]}
        />
        <:actions>
          <.button
            type="button"
            phx-click={JS.exec("data-cancel", to: "#generate-api-key-modal")}
            class="btn btn-ghost btn-sm"
          >
            Cancel
          </.button>
          <.button class="btn btn-primary btn-sm" phx-disable-with="Generating...">
            Generate key
          </.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    form = Lorito.Accounts.form_to_update_user(current_user, actor: current_user)

    socket =
      socket
      |> assign(form: to_form(form))
      |> assign(api_keys: [], plaintext_api_key: nil, plaintext_api_key_id: nil)
      |> assign(api_key_form: new_api_key_form(), show_api_key_modal: false, api_key_error: nil)

    case Lorito.Accounts.list_api_keys(actor: current_user) do
      {:ok, keys} -> {:ok, assign(socket, :api_keys, sort_keys(keys))}
      {:error, _} -> {:ok, put_flash(socket, :error, "Could not load API keys")}
    end
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

  def handle_event("open_api_key_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_api_key_modal: true,
       plaintext_api_key: nil,
       plaintext_api_key_id: nil,
       api_key_form: new_api_key_form(),
       api_key_error: nil
     )}
  end

  def handle_event("close_api_key_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_api_key_modal: false,
       api_key_error: nil,
       plaintext_api_key: nil,
       plaintext_api_key_id: nil
     )}
  end

  def handle_event("create_api_key", %{"api_key" => params}, socket) do
    with {:ok, expires_at} <- expiration_time(params["expiration"]),
         {:ok, key} <-
           Lorito.Accounts.create_api_key(%{name: params["name"], expires_at: expires_at},
             actor: socket.assigns.current_user
           ) do
      {:noreply,
       socket
       |> assign(
         api_keys: sort_keys([key | socket.assigns.api_keys]),
         plaintext_api_key: key.__metadata__.plaintext_api_key,
         plaintext_api_key_id: key.id,
         show_api_key_modal: true,
         api_key_error: nil,
         api_key_form: new_api_key_form()
       )
       |> put_flash(:info, "API key generated successfully")}
    else
      {:error, _} ->
        {:noreply,
         socket
         |> assign(
           api_key_form: to_form(params, as: :api_key),
           show_api_key_modal: true,
           api_key_error:
             "Could not generate API key. Enter a name (1–100 characters) and a valid expiration."
         )}
    end
  end

  def handle_event("revoke_api_key", %{"id" => id}, socket) do
    with %{} = key <- Enum.find(socket.assigns.api_keys, &(&1.id == id)),
         :ok <- Lorito.Accounts.destroy_api_key(key, actor: socket.assigns.current_user) do
      socket = assign(socket, :api_keys, Enum.reject(socket.assigns.api_keys, &(&1.id == id)))

      socket =
        if socket.assigns.plaintext_api_key_id == id,
          do: assign(socket, plaintext_api_key: nil, plaintext_api_key_id: nil),
          else: socket

      {:noreply, put_flash(socket, :info, "API key revoked")}
    else
      _ -> {:noreply, put_flash(socket, :error, "Could not revoke API key")}
    end
  end

  defp new_api_key_form, do: to_form(%{"name" => "", "expiration" => "never"}, as: :api_key)
  defp sort_keys(keys), do: Enum.sort_by(keys, &{String.downcase(&1.name), &1.id})

  defp expiration_time("never"), do: {:ok, nil}

  defp expiration_time(value) when value in ["1w", "1m", "1y"] do
    days = %{"1w" => 7, "1m" => 30, "1y" => 365}
    {:ok, DateTime.add(DateTime.utc_now(), days[value], :day)}
  end

  defp expiration_time(_), do: {:error, :invalid_expiration}

  defp expired?(nil), do: false
  defp expired?(expires_at), do: DateTime.compare(expires_at, DateTime.utc_now()) != :gt

  defp expiration_label(nil, _timezone), do: "No expiration"

  defp expiration_label(expires_at, timezone) do
    local = DateTime.shift_zone!(expires_at, timezone || "UTC")
    "Expires: " <> Calendar.strftime(local, "%Y-%m-%d %H:%M %Z")
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

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
