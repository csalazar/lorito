defmodule Lorito.Responses.ResponseRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Responses.Response
  alias Lorito.Accounts.User

  def list_responses(_filters \\ %{}) do
    Response
    |> Repo.all()
    |> Repo.preload(:user)
  end

  def get_response!(id), do: Repo.get!(Response, id) |> Repo.preload(:user)

  def create_response(attrs) do
    caller = User.get_user_from_process()

    %Response{}
    |> Response.changeset(attrs)
    |> User.put_user(caller)
    |> Repo.insert()
  end

  def update_response(%Response{} = response, attrs) do
    response
    |> Response.changeset(attrs)
    |> Repo.update()
  end

  def delete_response(%Response{} = response) do
    Repo.delete(response)
  end

  def change_response(%Response{} = response, attrs \\ %{}) do
    Response.changeset(response, attrs)
  end
end
