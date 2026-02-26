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
  end
end
