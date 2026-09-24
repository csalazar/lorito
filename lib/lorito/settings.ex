defmodule Lorito.Settings do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix, AshAi]

  tools do
    tool :get_settings, Lorito.Settings.Setting, :get_settings do
      description "Get the stored application settings, including DNS configuration and scoped logging mode. Takes no arguments."
    end
  end

  resources do
    resource Lorito.Settings.Setting do
      define :get_settings, action: :read, get?: true
      define :update_settings, action: :update
    end
  end
end
