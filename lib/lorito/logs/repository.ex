defmodule Lorito.Logs.LogsRepo do
  import Ecto.Query, warn: false
  alias Lorito.Repo

  alias Lorito.Logs.Log

  def filter_scoped_logs(query, %{scoped_logs: true}) do
    where(query, [l], not is_nil(l.project_id))
  end

  def filter_scoped_logs(query, _), do: query

  def list_logs(filters \\ %{}) do
    Log
    |> filter_scoped_logs(filters)
    |> limit(^100)
    |> order_by([l], desc: l.inserted_at)
    |> Repo.all()
    |> Repo.preload([:project, :workspace])
    |> Enum.map(&Log.populate_host_field/1)
  end

  def get_log!(id),
    do: Repo.get!(Log, id) |> Repo.preload([:project, :workspace]) |> Log.populate_host_field()

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

  def delete_logs(%{type: :catch_all}) do
    Repo.delete_all(from l in Log, where: is_nil(l.project_id), select: l)
  end

  def change_log(%Log{} = log, attrs \\ %{}) do
    Log.changeset(log, attrs)
  end
end
