defmodule LoritoWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides

  override AshAuthentication.Phoenix.Components.Banner do
    set :image_url, "/images/logo.svg"
    set :dark_image_url, "/images/logo-dark.svg"
  end
end
