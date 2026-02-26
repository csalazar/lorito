defmodule LoritoWeb.UserSettingsLive do
  use LoritoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
    </.header>

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
        <.button class="btn btn-primary" phx-disable-with="Changing...">Save</.button>
      </:actions>
    </.simple_form>
    """
  end

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    form = Lorito.Accounts.form_to_update_user(current_user, actor: current_user)

    {:ok,
     socket
     |> assign(form: to_form(form))}
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
