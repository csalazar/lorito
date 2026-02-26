defmodule LoritoWeb.IntegrationLive.FormComponent do
  use LoritoWeb, :live_component

  alias Lorito.Logs

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage integration records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="integration-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input
          field={@form[:type]}
          type="select"
          label="Type"
          prompt="Choose a value"
          options={[{"discord", "discord"}]}
        />
        <.input field={@form[:webhook_url]} type="text" label="Webhook url" />
        <:actions>
          <.button class="btn btn-primary" phx-disable-with="Saving...">Save Integration</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{action: :new, current_user: current_user} = assigns, socket) do
    form = Logs.form_to_create_integration(actor: current_user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def update(%{action: :edit, integration: integration} = assigns, socket) do
    form = Logs.form_to_update_integration(integration)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => form_data}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
      {:ok, integration} ->
        notify_parent({:saved, integration})

        socket =
          socket
          |> put_flash(:info, "Integration saved successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, "Could not save project data")
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
