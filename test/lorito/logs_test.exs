defmodule Lorito.LogsTest do
  use Lorito.DataCase

  alias Lorito.Logs
  import Lorito.AccountsFixtures

  setup do
    owner = user_fixture()

    Lorito.Repo.put_user(owner)

    {:ok, owner: owner}
  end

  describe "logs" do
    alias Lorito.Logs.Log

    import Lorito.LogsFixtures

    @invalid_attrs %{ip: nil, body: nil, url: nil, headers: [], method: nil}

    test "list_logs/0 returns all logs" do
      log = log_fixture() |> Repo.preload([:project, :workspace])
      assert Logs.list_logs() == [log]
    end

    test "get_log!/1 returns the log with given id" do
      log = log_fixture() |> Repo.preload([:project, :workspace])
      assert Logs.get_log!(log.id) == log
    end

    test "create_log/1 with valid data creates a log" do
      valid_attrs = %{
        ip: "some ip",
        body: "some body",
        url: "some url",
        headers: [["x-header", "value"]],
        method: "GET"
      }

      assert {:ok, %Log{} = log} = Logs.create_log(valid_attrs)
      assert log.ip == "some ip"
      assert log.body == "some body"
      assert log.url == "some url"
      assert log.headers == [["x-header", "value"]]
      assert log.method == "GET"
    end

    test "create_log/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Logs.create_log(@invalid_attrs)
    end

    test "update_log/2 with valid data updates the log" do
      log = log_fixture()

      update_attrs = %{
        ip: "some updated ip",
        body: "some updated body",
        url: "some updated url",
        headers: [["x-header", "value"]],
        method: "GET"
      }

      assert {:ok, %Log{} = log} = Logs.update_log(log, update_attrs)
      assert log.ip == "some updated ip"
      assert log.body == "some updated body"
      assert log.url == "some updated url"
      assert log.headers == [["x-header", "value"]]
      assert log.method == "GET"
    end

    test "update_log/2 with invalid data returns error changeset" do
      log = log_fixture() |> Repo.preload([:project, :workspace])
      assert {:error, %Ecto.Changeset{}} = Logs.update_log(log, @invalid_attrs)
      assert log == Logs.get_log!(log.id)
    end

    test "delete_log/1 deletes the log" do
      log = log_fixture()
      assert {:ok, %Log{}} = Logs.delete_log(log)
      assert_raise Ecto.NoResultsError, fn -> Logs.get_log!(log.id) end
    end

    test "change_log/1 returns a log changeset" do
      log = log_fixture()
      assert %Ecto.Changeset{} = Logs.change_log(log)
    end
  end
end
