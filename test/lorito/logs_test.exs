defmodule Lorito.LogsTest do
  use Lorito.DataCase
  import Mock

  import Lorito.Test.Generators

  describe "logs" do
    test "list scoped logs" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))

      log1 = generate(http_log(project_id: project.id))
      log2 = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      generate(http_log())

      logs = Lorito.Logs.list_logs!(%{scoped_logs: true})
      assert Enum.map(logs, & &1.id) == [log2.id, log1.id]

      logs = Lorito.Logs.list_logs!(%{scoped_logs: false})
      assert Enum.count(logs) == 3
    end

    test "list logs by project" do
      user = generate(user())
      project = generate(project(actor: user))
      other_project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))

      project_log = generate(http_log(project_id: project.id))
      workspace_log = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      generate(http_log(project_id: other_project.id))
      generate(http_log())

      logs = Lorito.Logs.list_logs!(%{project_id: project.id})

      assert Enum.map(logs, & &1.id) == [workspace_log.id, project_log.id]
      assert Enum.all?(logs, &(&1.project_id == project.id))
    end

    test "list logs by workspace" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      other_workspace = generate(workspace(project: project, actor: user))

      workspace_log = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      generate(http_log(project_id: project.id, workspace_id: other_workspace.id))
      generate(http_log(project_id: project.id))

      logs = Lorito.Logs.list_logs!(%{workspace_id: workspace.id})

      assert Enum.map(logs, & &1.id) == [workspace_log.id]
      assert Enum.all?(logs, &(&1.workspace_id == workspace.id))
    end

    test "list logs by project and workspace" do
      user = generate(user())
      project = generate(project(actor: user))
      other_project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))

      workspace_log = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      generate(http_log(project_id: other_project.id, workspace_id: workspace.id))
      generate(http_log(project_id: project.id))

      logs = Lorito.Logs.list_logs!(%{project_id: project.id, workspace_id: workspace.id})

      assert Enum.map(logs, & &1.id) == [workspace_log.id]
    end

    test "list logs by inserted_after" do
      old_log = generate(http_log())
      boundary_log = generate(http_log())
      recent_log = generate(http_log())

      old_inserted_at = utc_datetime(2026, 6, 29, 9, 59, 59)
      boundary = utc_datetime(2026, 6, 29, 10, 0, 0)
      recent_inserted_at = utc_datetime(2026, 6, 29, 10, 0, 1)

      set_http_log_inserted_at(old_log, old_inserted_at)
      set_http_log_inserted_at(boundary_log, boundary)
      set_http_log_inserted_at(recent_log, recent_inserted_at)

      logs = Lorito.Logs.list_logs!(%{inserted_after: boundary})

      assert Enum.map(logs, & &1.id) == [recent_log.id, boundary_log.id]
      refute Enum.any?(logs, &(&1.id == old_log.id))
    end

    test "list logs by inserted_after and project" do
      user = generate(user())
      project = generate(project(actor: user))
      other_project = generate(project(actor: user))

      old_project_log = generate(http_log(project_id: project.id))
      project_log = generate(http_log(project_id: project.id))
      other_project_log = generate(http_log(project_id: other_project.id))

      boundary = utc_datetime(2026, 6, 29, 10, 0, 0)

      set_http_log_inserted_at(old_project_log, utc_datetime(2026, 6, 29, 9, 59, 59))
      set_http_log_inserted_at(project_log, utc_datetime(2026, 6, 29, 10, 0, 1))
      set_http_log_inserted_at(other_project_log, utc_datetime(2026, 6, 29, 10, 0, 2))

      logs = Lorito.Logs.list_logs!(%{project_id: project.id, inserted_after: boundary})

      assert Enum.map(logs, & &1.id) == [project_log.id]
    end

    test "list logs by inserted_after and workspace" do
      user = generate(user())
      project = generate(project(actor: user))
      workspace = generate(workspace(project: project, actor: user))
      other_workspace = generate(workspace(project: project, actor: user))

      old_workspace_log = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      workspace_log = generate(http_log(project_id: project.id, workspace_id: workspace.id))

      other_workspace_log =
        generate(http_log(project_id: project.id, workspace_id: other_workspace.id))

      boundary = utc_datetime(2026, 6, 29, 10, 0, 0)

      set_http_log_inserted_at(old_workspace_log, utc_datetime(2026, 6, 29, 9, 59, 59))
      set_http_log_inserted_at(workspace_log, utc_datetime(2026, 6, 29, 10, 0, 1))
      set_http_log_inserted_at(other_workspace_log, utc_datetime(2026, 6, 29, 10, 0, 2))

      logs = Lorito.Logs.list_logs!(%{workspace_id: workspace.id, inserted_after: boundary})

      assert Enum.map(logs, & &1.id) == [workspace_log.id]
    end

    test "list logs keeps the default 100 log cap" do
      for _ <- 1..101 do
        generate(http_log())
      end

      logs = Lorito.Logs.list_logs!(%{scoped_logs: false})

      assert length(logs) == 100
    end

    test "mixed HTTP and DNS logs apply combined filters and inclusive time boundaries" do
      actor = generate(user())
      project = generate(project(actor: actor))
      workspace = generate(workspace(project: project, actor: actor))
      other = generate(workspace(project: project, actor: actor))
      boundary = utc_datetime(2026, 6, 29, 10, 0, 0)

      http = generate(http_log(project_id: project.id, workspace_id: workspace.id))
      dns = generate(dns_log(project_id: project.id, workspace_id: workspace.id))
      old = generate(dns_log(project_id: project.id, workspace_id: workspace.id))
      generate(dns_log(project_id: project.id, workspace_id: other.id))
      generate(dns_log())
      set_http_log_inserted_at(http, DateTime.add(boundary, 1))
      set_dns_log_inserted_at(dns, boundary)
      set_dns_log_inserted_at(old, DateTime.add(boundary, -1))

      logs =
        Lorito.Logs.list_logs!(%{
          scoped_logs: true,
          project_id: project.id,
          workspace_id: workspace.id,
          inserted_after: DateTime.to_iso8601(boundary)
        })

      assert Enum.map(logs, & &1.id) == [http.id, dns.id]
      assert [] == Lorito.Logs.list_logs!(%{project_id: "missing"})
    end

    test "the 100 log cap selects the newest records across both protocols" do
      boundary = utc_datetime(2026, 6, 29, 10, 0, 0)

      records =
        for offset <- 0..100 do
          if rem(offset, 2) == 0 do
            log = generate(http_log())
            set_http_log_inserted_at(log, DateTime.add(boundary, offset))
            log
          else
            log = generate(dns_log())
            set_dns_log_inserted_at(log, DateTime.add(boundary, offset))
            log
          end
        end

      assert Enum.map(Lorito.Logs.list_logs!(), & &1.id) ==
               records |> Enum.reverse() |> Enum.take(100) |> Enum.map(& &1.id)
    end

    test "list_logs is exposed as an MCP tool" do
      tools =
        AshAi.exposed_tools(
          otp_app: :lorito,
          tools: [
            :list_projects,
            :create_project,
            :list_workspaces_by_project,
            :create_workspace,
            :get_project_by_name,
            :create_response_for_workspace,
            :list_logs
          ]
        )

      assert Enum.any?(tools, &(&1.name == :list_logs))
    end

    test "send notification for project if notifiable is true" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: true, actor: user))

      with_mock Lorito.Logs, [:passthrough],
        send_integration_notification: fn _i, _l -> :ok end do
        generate(http_log(project_id: project.id))
        assert_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "don't send notification for project if notifiable is false" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))

      with_mock Lorito.Logs, [:passthrough],
        send_integration_notification: fn _i, _l -> :ok end do
        generate(http_log(project_id: project.id))
        assert_not_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "send notification for workspace if notifiable is true" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, notifiable: true, actor: user))

      with_mock Lorito.Logs, [:passthrough],
        send_integration_notification: fn _i, _l -> :ok end do
        generate(http_log(project_id: project.id, workspace_id: workspace.id))
        assert_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    test "don't send notification for workspace if notifiable is false" do
      user = generate(user())
      generate(integration(actor: user))
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, notifiable: false, actor: user))

      with_mock Lorito.Logs, [:passthrough],
        send_integration_notification: fn _i, _l -> :ok end do
        generate(http_log(project_id: project.id, workspace_id: workspace.id))
        assert_not_called(Lorito.Logs.send_integration_notification(:_, :_))
      end
    end

    for protocol <- [:http, :dns] do
      test "delete #{protocol} log by ID preserves unrelated logs" do
        target =
          case unquote(protocol) do
            :http -> generate(http_log())
            :dns -> generate(dns_log())
          end

        other_http = generate(http_log())
        other_dns = generate(dns_log())

        assert {:ok, true} = Lorito.Logs.delete_log_by_id(target.id)
        assert {:ok, nil} = Ash.get(Lorito.Logs.Log, target.id, not_found_error?: false)

        resource = Lorito.Logs.Helpers.log_protocol_to_module(unquote(protocol))
        assert {:ok, nil} = Ash.get(resource, target.id, not_found_error?: false)

        assert MapSet.new(Enum.map(Lorito.Logs.list_logs!(), & &1.id)) ==
                 MapSet.new([other_http.id, other_dns.id])
      end
    end

    test "delete log by ID rejects missing and invalid IDs" do
      assert {:error, error} = Lorito.Logs.delete_log_by_id(Ash.UUID.generate())
      assert Exception.message(error) =~ "not found"
      assert {:error, _} = Lorito.Logs.delete_log_by_id("invalid")
      assert {:error, _} = Lorito.Logs.delete_log_by_id(nil)
    end

    test "delete_log is exposed as an MCP tool with a required UUID" do
      assert [tool] = AshAi.exposed_tools(otp_app: :lorito, tools: [:delete_log])
      assert tool.name == :delete_log
      assert tool.action.name == :delete_log_by_id

      action = Ash.Resource.Info.action(Lorito.Logs.Log, :delete_log_by_id)
      assert [argument] = action.arguments
      assert argument.name == :log_id
      assert argument.type == Ash.Type.UUID
      refute argument.allow_nil?
    end

    test "existing struct-based delete_log still works" do
      log = generate(http_log())
      assert :ok = Lorito.Logs.delete_log(Lorito.Logs.get_log_by_id!(log.id))
      assert {:ok, nil} = Ash.get(Lorito.Logs.HTTP, log.id, not_found_error?: false)
    end

    test "delete logs by ip" do
      generate(http_log(ip: "127.0.0.1"))
      generate(http_log(ip: "127.0.0.1"))
      generate(http_log(ip: "192.168.0.1"))

      :ok = Lorito.Logs.delete_logs_by_ip("127.0.0.1")
      assert Lorito.Logs.list_logs!(%{scoped_logs: false}) |> Enum.count() == 1
    end

    test "delete catch-all logs" do
      user = generate(user())
      project = generate(project(notifiable: false, actor: user))
      workspace = generate(workspace(project: project, actor: user))

      generate(http_log(ip: "127.0.0.1"))
      generate(http_log(ip: "127.0.0.1"))
      generate(http_log(ip: "127.0.0.1", project_id: project.id))
      generate(http_log(ip: "127.0.0.1", project_id: project.id, workspace_id: workspace.id))

      :ok = Lorito.Logs.delete_logs_by_type(:catch_all)
      assert Lorito.Logs.list_logs!(%{scoped_logs: true}) |> Enum.count() == 2
    end
  end

  defp utc_datetime(year, month, day, hour, minute, second) do
    DateTime.new!(Date.new!(year, month, day), Time.new!(hour, minute, second), "Etc/UTC")
  end

  defp set_dns_log_inserted_at(log_record, inserted_at) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE dns_logs SET inserted_at = $1, updated_at = $1 WHERE id = $2::uuid",
      [inserted_at, Ecto.UUID.dump!(log_record.id)]
    )
  end

  defp set_http_log_inserted_at(log_record, inserted_at) do
    Ecto.Adapters.SQL.query!(
      Repo,
      "UPDATE http_logs SET inserted_at = $1, updated_at = $1 WHERE id = $2::uuid",
      [inserted_at, Ecto.UUID.dump!(log_record.id)]
    )
  end
end
