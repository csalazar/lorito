defmodule Lorito.Integrations.IntegrationRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Integrations.Integration
  alias Lorito.Accounts.User

  def list_integrations(_filters \\ %{}) do
    Repo.all(Integration) |> Repo.preload(:user)
  end

  def get_integration!(id), do: Repo.get!(Integration, id) |> Repo.preload(:user)

  def create_integration(attrs \\ %{}) do
    caller = User.get_user_from_process()

    %Integration{}
    |> Integration.changeset(attrs)
    |> User.put_user(caller)
    |> Repo.insert()
  end

  def update_integration(%Integration{} = integration, attrs) do
    integration
    |> Integration.changeset(attrs)
    |> Repo.update()
  end

  def delete_integration(%Integration{} = integration) do
    Repo.delete(integration)
  end

  def change_integration(%Integration{} = integration, attrs \\ %{}) do
    Integration.changeset(integration, attrs)
  end
end
