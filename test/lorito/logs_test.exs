defmodule Lorito.LogsTest do
  use Lorito.DataCase
  import Mock

  import Lorito.Test.Generators

  describe "logs" do
    test "list scoped logs" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))

      log1 = generate(log(project_id: project.id))
      log2 = generate(log(project_id: project.id, workspace_id: workspace.id))
      generate(log())

      logs = Lorito.Logs.list_logs!(%{scoped_logs: true})
      assert Enum.map(logs, & &1.id) == [log2.id, log1.id]

      logs = Lorito.Logs.list_logs!(%{scoped_logs: false})
      assert Enum.count(logs) == 3
    end

    test "send notification for project if notifiable is true" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: true, actor: user))

      with_mock Lorito.Logs, [:passthrough], send_integration_notification: fn _i, _l -> :ok end do
        generate(log(project_id: project.id))
        assert_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "don't send notification for project if notifiable is false" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))

      with_mock Lorito.Logs, [:passthrough], send_integration_notification: fn _i, _l -> :ok end do
        generate(log(project_id: project.id))
        assert_not_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "send notification for workspace if notifiable is true" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, notifiable: true, actor: user))

      with_mock Lorito.Logs, [:passthrough], send_integration_notification: fn _i, _l -> :ok end do
        generate(log(project_id: project.id, workspace_id: workspace.id))
        assert_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "don't send notification for workspace if notifiable is false" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, notifiable: false, actor: user))

      with_mock Lorito.Logs, [:passthrough], send_integration_notification: fn _i, _l -> :ok end do
        generate(log(project_id: project.id, workspace_id: workspace.id))
        assert_not_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "delete logs by ip" do
      log1 = generate(log(ip: "127.0.0.1"))
      log2 = generate(log(ip: "127.0.0.1"))
      _log3 = generate(log(ip: "192.168.0.1"))

      {_n, deleted_logs} = Lorito.Logs.delete_logs_by_ip("127.0.0.1")
      assert Enum.map(deleted_logs, & &1.id) == [log1.id, log2.id]
    end

    test "delete catch-all logs" do
      user = generate(user())
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, actor: user))

      log1 = generate(log(ip: "127.0.0.1"))
      log2 = generate(log(ip: "127.0.0.1"))
      _log3 = generate(log(ip: "127.0.0.1", project_id: project.id))
      _log4 = generate(log(ip: "127.0.0.1", project_id: project.id, workspace_id: workspace.id))

      {_n, deleted_logs} = Lorito.Logs.delete_logs_by_type(:catch_all)
      assert Enum.map(deleted_logs, & &1.id) == [log1.id, log2.id]
    end
  end
end
