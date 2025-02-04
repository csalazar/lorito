defmodule LoritoWeb.UserSettingsLive do
  use LoritoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
    </.header>

    <.simple_form for={@form} id="settings-form" phx-submit="save">
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
    changeset = Lorito.Accounts.change_user_settings(socket.assigns.current_user)

    {:ok,
     socket
     |> assign_form(changeset)}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Lorito.Accounts.update_user(socket.assigns.current_user, user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "User updated successfully")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
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
end
