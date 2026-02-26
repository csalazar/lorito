defmodule LoritoWeb.WorkspaceLive.FormComponent do
  use LoritoWeb, :live_component

  alias Lorito.Workspaces

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage workspace records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="workspace-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" />
        <.input field={@form[:path]} type="text" label="Custom path" />

        <.input
          :if={!@project.notifiable}
          field={@form[:notifiable]}
          type="checkbox"
          label="Send notifications?"
        />

        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Workspace</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{action: :edit, workspace: workspace} = assigns, socket) do
    form = Workspaces.form_to_update_workspace(workspace)

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
      {:ok, workspace} ->
        notify_parent({:saved, workspace})

        socket =
          socket
          |> put_flash(:info, "Workspace saved successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, "Could not save workspace data")
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
