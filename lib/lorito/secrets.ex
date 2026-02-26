defmodule Lorito.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Lorito.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:lorito, :token_signing_secret)
  end
end
