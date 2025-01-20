defmodule Lorito.Logs.LogsRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Logs.Log

  def list_logs(_filters \\ %{}) do
    Repo.all(from l in Log, limit: 100, order_by: [desc: l.inserted_at])
    |> Repo.preload([:project, :workspace])
  end

  def get_log!(id), do: Repo.get!(Log, id) |> Repo.preload([:project, :workspace])

  def create_log(attrs \\ %{}) do
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end

  def update_log(%Log{} = log, attrs) do
    log
    |> Log.changeset(attrs)
    |> Repo.update()
  end

  def delete_log(%Log{} = log) do
    Repo.delete(log)
  end

  def delete_logs(%{ip: ip}) do
    Repo.delete_all(from l in Log, where: l.ip == ^ip, select: l)
  end

  def change_log(%Log{} = log, attrs \\ %{}) do
    Log.changeset(log, attrs)
  end
end
