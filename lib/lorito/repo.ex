defmodule Lorito.Repo do
  use Ecto.Repo,
    otp_app: :lorito,
    adapter: Ecto.Adapters.Postgres

  require Ecto.Query

  @tenant_key {__MODULE__, :user}

  def put_user(user) do
    Process.put(@tenant_key, user)
  end

  def get_user() do
    Process.get(@tenant_key)
  end
end
