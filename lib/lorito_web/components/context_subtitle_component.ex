import LoritoWeb.CoreComponents, only: [icon: 1]

defmodule LoritoWeb.ContextSubtitleComponent do
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    display_name = Map.get(assigns, :display_name, true)
    assigns = assign(assigns, :display_name, display_name)

    ~H"""
    <div class="flex flex-row space-x-2 mb-4">
      <div :if={@display_name} class="badge badge-xs badge-neutral p-4">
        <div class="flex space-x-4">
          <div class="font-mono flex items-center space-x-2">
            <span>
              project: <span class="font-bold">{@project.name}</span>
            </span>
            <.icon :if={@project.notifiable} name="hero-bell-alert" />
          </div>
        </div>
      </div>
      <div :if={@project.subdomain} class="badge badge-xs badge-neutral p-4">
        <div class="flex space-x-4">
          <div class="font-mono ">
            subdomain: <span class="font-bold">{@project.subdomain}</span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
