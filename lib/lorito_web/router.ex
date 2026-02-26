defmodule LoritoWeb.Router do
  use LoritoWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :api do
    plug :load_from_bearer
    plug :set_actor, :user
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {LoritoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :public do
    plug :accepts, ~w(html json)
  end

  scope "/_lorito", LoritoWeb do
    pipe_through [:browser]
    auth_routes AuthController, Lorito.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route auth_routes_prefix: "/auth",
                  on_mount: [{LoritoWeb.LiveUserAuth, :live_no_user}],
                  overrides: [AshAuthentication.Phoenix.Overrides.DaisyUI]
  end

  scope "/_lorito", LoritoWeb do
    pipe_through :browser

    ash_authentication_live_session :authentication_required,
      on_mount: [{LoritoWeb.LiveUserAuth, :live_user_required}] do
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
      live "/templates/:id/edit", TemplateLive.Index, :edit

      live "/templates/:id", TemplateLive.Show, :show
      live "/templates/:id/show/edit", TemplateLive.Show, :edit

      live "/templates/:id/responses/new", TemplateLive.Show, :new_response

      live "/templates/:id/responses/:response_id/edit",
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

  scope "/", LoritoWeb do
    pipe_through :public

    match :*, "/*route", PublicController, :process_requests
  end
end
