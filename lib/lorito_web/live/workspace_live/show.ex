defmodule LoritoWeb.WorkspaceLive.Show do
  use LoritoWeb, :live_view

  alias Lorito.Workspaces
  alias Lorito.Responses
  alias Lorito.Logs
  alias Lorito.Responses.Response
  alias Lorito.Workspaces.Workspace

  @impl true
  def mount(_params, _session, %{assigns: %{workspace: workspace}} = socket) do
    if connected?(socket), do: Logs.PubSub.subscribe(workspace.id)

    {:ok, socket |> stream(:responses, workspace.responses) |> stream(:logs, workspace.logs)}
  end

  @impl true
  def handle_params(
        %{"workspace_id" => workspace_id} = params,
        _,
        socket
      ) do
    response =
      case Map.get(params, "response_id") do
        nil -> %Response{}
        response_id -> Responses.get_response!(response_id)
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:workspace, Workspaces.get_workspace!(workspace_id))
     |> assign(:response, response)}
  end

  defp page_title(:show), do: "Show Workspace"
  defp page_title(:edit), do: "Edit Workspace"
  defp page_title(:new_response), do: "New response"
  defp page_title(:edit_response), do: "Edit response"

  @impl true
  def handle_event("delete_response", %{"id" => id}, %{assigns: %{workspace: workspace}} = socket) do
    response = Responses.get_response!(id)
    {:ok, _} = Responses.delete_response(response)

    rebound_routes = Enum.map(workspace.rebindings, fn r -> r.route end)

    if Enum.member?(rebound_routes, response.route) do
      {:ok, _} = Lorito.Workspaces.demote_response_from_rebindings(workspace, response)
    end

    workspace = Workspaces.get_workspace!(workspace.id)

    {:noreply,
     socket
     |> stream(:responses, workspace.responses, reset: true)
     |> assign(workspace: workspace)}
  end

  @impl true
  def handle_event("delete_log", %{"id" => id}, socket) do
    log = Logs.get_log!(id)
    {:ok, _} = Logs.delete_log(log)

    {:noreply, stream_delete(socket, :logs, log)}
  end

  @impl true
  def handle_event(
        "activate_rebinding",
        %{"id" => id},
        %{assigns: %{workspace: workspace}} = socket
      ) do
    response = Responses.get_response!(id)
    Workspaces.Rebindings.activate_response(workspace, response)
    workspace = Workspaces.get_workspace!(workspace.id)

    {:noreply,
     socket
     |> stream(:responses, workspace.responses, reset: true)
     |> assign(workspace: workspace)}
  end

  @impl true
  def handle_info(
        {LoritoWeb.ResponseLive.FormComponent, {:saved, response}},
        %{assigns: %{workspace: workspace}} = socket
      ) do
    existing_routes = Enum.map(workspace.responses, fn r -> r.route end) |> Enum.frequencies()

    if Map.get(existing_routes, response.route) > 1 do
      {:ok, _} = Lorito.Workspaces.promote_response_to_rebinding(workspace, response)
    end

    workspace = Workspaces.get_workspace!(workspace.id)

    {:noreply,
     socket
     |> stream(:responses, workspace.responses, reset: true)
     |> assign(workspace: workspace)}
  end

  @impl true
  def handle_info({Lorito.Logs.PubSub, [:log, :created], log}, socket) do
    {:noreply, stream_insert(socket, :logs, log, at: 0)}
  end

  @impl true
  def handle_info({LoritoWeb.WorkspaceLive.FormComponent, {:saved, _workspace}}, socket) do
    {:noreply, socket}
  end

  def determine_relative_url(workspace, path) do
    case String.replace(path, Workspace.get_path(workspace), "") do
      "" -> "/"
      uri -> uri
    end
  end

  def get_copy_payload_url(copy_payload, workspace) do
    workspace_url = LoritoWeb.Utils.build_workspace_url(workspace)

    with {:ok, template} <- Solid.parse(copy_payload) do
      Solid.render!(template, %{"workspace_url" => workspace_url},
        custom_filters: LoritoWeb.Utils.SolidCustomFilters
      )
      |> to_string()
    end
  end

  def display_route(%{workspace: workspace, response: response}) do
    {rebinding, is_response_active} =
      case Workspaces.Rebindings.get_rebinding(workspace, response.route) do
        {:ok, rebinding} ->
          is_response_active = Workspaces.Rebindings.is_response_active?(rebinding, response)
          {rebinding, is_response_active}

        {:not_found, _} ->
          {nil, false}
      end

    assigns = %{
      rebinding: rebinding,
      response: response,
      is_response_active: is_response_active
    }

    ~H"""
    <div class="flex grow space-x-2">
      <%= if @rebinding do %>
        <span class={!@is_response_active && "opacity-40"}>
          {@rebinding.icon}
        </span>
      <% end %>

      <span>
        {@response.route}
      </span>

      <.link
        :if={@rebinding != nil and !@is_response_active}
        phx-click={JS.push("activate_rebinding", value: %{id: @response.id})}
        class="btn btn-ghost btn-xs"
      >
        <.icon name="hero-arrow-path-rounded-square" />
      </.link>
    </div>
    """
  end
end
