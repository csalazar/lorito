defmodule Lorito.Accounts do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  resources do
    resource Lorito.Accounts.Token

    resource Lorito.Accounts.User do
      define :get_user_by_email, args: [:email], action: :get_by_email
      define :register_user, action: :register
      define :update_user, action: :update
    end

    resource Lorito.Accounts.ApiKey do
      define :create_api_key, action: :create
      define :list_api_keys, action: :read
      define :destroy_api_key, action: :destroy
    end
  end
end
