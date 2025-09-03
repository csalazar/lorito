import LoritoWeb.UserAuth

defmodule Lorito.InitAssigns do
  use Phoenix.Component

  alias Lorito.{Projects, Workspaces}

  def on_mount(:project, params, _session, socket) do
    project =
      case Map.get(params, "project_id") do
        nil ->
          nil

        id ->
          Projects.get_project!(id)
      end

    workspace =
      case Map.get(params, "workspace_id") do
        nil ->
          nil

        id ->
          Workspaces.get_workspace!(id)
      end

    socket =
      socket
      |> assign(project: project, workspace: workspace)

    {:cont, socket}
  end
end

defmodule LoritoWeb.Router do
  use LoritoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LoritoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :public do
    plug :accepts, ~w(html json)
  end

  scope "/_lorito", LoritoWeb do
    pipe_through :browser

    live_session :default,
      on_mount: [{LoritoWeb.UserAuth, :ensure_authenticated}, {Lorito.InitAssigns, :project}] do
      live "/", ProjectLive.Index, :index
      live "/projects", ProjectLive.Index, :index
      live "/projects/new", ProjectLive.Index, :new

      live "/logs", LogLive.Index, :log_index
      live "/logs/:id", LogLive.Show, :log_show

      live "/integrations", IntegrationLive.Index, :index
      live "/integrations/new", IntegrationLive.Index, :new
      live "/integrations/:id/edit", IntegrationLive.Index, :edit

      live "/integrations/:id", IntegrationLive.Show, :show
      live "/integrations/:id/show/edit", IntegrationLive.Show, :edit

      live "/templates", TemplateLive.Index, :index
      live "/templates/new", TemplateLive.Index, :new
      live "/templates/:template_id/edit", TemplateLive.Index, :edit

      live "/templates/:template_id", TemplateLive.Show, :show
      live "/templates/:template_id/show/edit", TemplateLive.Show, :edit

      live "/templates/:template_id/responses/new", TemplateLive.Show, :new_response

      live "/templates/:template_id/responses/:response_id/edit",
           TemplateLive.Show,
           :edit_response

      live "/users/settings", UserSettingsLive, :edit

      scope("/projects/:project_id") do
        live "/edit", ProjectLive.Index, :edit

        live "/workspaces", WorkspaceLive.Index, :index
        live "/workspaces/from_template", WorkspaceLive.Index, :add_new_workspace_from_template
        live "/workspaces/edit_project", WorkspaceLive.Index, :edit_project
        live "/workspaces/:workspace_id", WorkspaceLive.Show, :show
        live "/workspaces/:workspace_id/edit", WorkspaceLive.Index, :edit
        live "/workspaces/:workspace_id/show/edit", WorkspaceLive.Show, :edit

        live "/workspaces/:workspace_id/responses/new", WorkspaceLive.Show, :new_response

        live "/workspaces/:workspace_id/responses/:response_id/edit_from_workspace",
             WorkspaceLive.Show,
             :edit_response

        live "/workspaces/:workspace_id/responses/:id/edit", ResponseLive.Index, :edit

        live "/workspaces/:workspace_id/responses/:id", ResponseLive.Show, :show
        live "/workspaces/:workspace_id/responses/:id/show/edit", ResponseLive.Show, :edit

        live "/workspaces/:workspace_id/logs/:id", LogLive.Show, :workspace_log_show
      end
    end
  end

  scope "/_lorito", LoritoWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{LoritoWeb.UserAuth, :redirect_if_user_is_authenticated}] do
      live "/users/log_in", UserLoginLive, :new
    end

    post "/users/log_in", UserSessionController, :create
  end

  scope "/_lorito", LoritoWeb do
    pipe_through [:browser]

    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/", LoritoWeb do
    pipe_through :public

    match :*, "/*route", PublicController, :process_requests
  end
end
