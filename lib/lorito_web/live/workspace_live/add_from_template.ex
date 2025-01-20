defmodule LoritoWeb.WorkspaceLive.AddNewWorkspaceFromTemplateFormComponent do
  use LoritoWeb, :live_component

  alias Lorito.Workspaces
  alias Lorito.Templates

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
        <.input
          type="select"
          field={@form[:template_id]}
          options={
            for template <- Lorito.Templates.list_templates() do
              {template.name, template.id}
            end
          }
          label="Template"
          prompt="Select a template .."
        />
        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Workspace</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{workspace: workspace} = assigns, socket) do
    changeset = Workspaces.change_workspace(workspace)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"workspace" => workspace_params}, socket) do
    changeset =
      socket.assigns.workspace
      |> Workspaces.change_workspace(workspace_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"workspace" => workspace_params}, socket) do
    save_workspace(socket, socket.assigns.action, workspace_params)
  end

  defp save_workspace(
         %{assigns: %{project: project}} = socket,
         :add_new_workspace_from_template,
         workspace_params
       ) do
    {template_id, workspace_params} = Map.pop(workspace_params, "template_id")

    workspace_params =
      Map.put(workspace_params, "project", project)
      |> Map.put("template", Templates.get_template!(template_id))

    case Workspaces.create_workspace(workspace_params) do
      {:ok, workspace} ->
        notify_parent({:saved, workspace})

        {:noreply,
         socket
         |> put_flash(:info, "Workspace created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
