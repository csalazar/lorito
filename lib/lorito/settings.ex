defmodule Lorito.Settings do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  resources do
    resource Lorito.Settings.Setting do
      define :get_settings, action: :read, get?: true
      define :update_settings, action: :update
    end
  end
end
