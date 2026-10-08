defmodule LoritoWeb.TransportErrorLogger do
  @moduledoc false

  use GenServer

  require Logger

  alias Lorito.Logs
  alias Lorito.Projects

  @events [
    [:cowboy, :request, :early_error],
    [:cowboy, :request, :exception],
    [:cowboy, :request, :stop]
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    case :telemetry.attach_many(__MODULE__, @events, &__MODULE__.handle_event/4, nil) do
      :ok -> :ok
      {:error, :already_exists} -> :ok
    end

    {:ok, nil}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach(__MODULE__)
  end

  # Normal stops are already handled by RequestLogger. Cowboy only includes
  # :error on stop events when transport/protocol processing failed.
  def handle_event([:cowboy, :request, :stop], _measurements, metadata, _config)
      when not is_map_key(metadata, :error),
      do: :ok

  def handle_event(_event, _measurements, metadata, _config) do
    GenServer.cast(__MODULE__, {:persist, metadata})
  end

  @impl true
  def handle_cast({:persist, metadata}, state) do
    case Task.Supervisor.start_child(Lorito.TransportErrorTaskSupervisor, fn ->
           persist(metadata)
         end) do
      {:ok, _pid} ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not start transport error logger: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  @doc false
  def persist(metadata) do
    request = Map.get(metadata, :partial_req) || Map.get(metadata, :req) || %{}

    if internal_request?(request) do
      :ignored
    else
      attributes = attributes(request, metadata)

      case scope(attributes, request) do
        {:workspace, workspace} ->
          attributes
          |> Map.put(:workspace_id, workspace.id)
          |> Map.put(:project_id, workspace.project_id)
          |> Logs.create_http_log()

        {:project, project} ->
          attributes
          |> Map.put(:project_id, project.id)
          |> Logs.create_http_log()

        :global ->
          if Lorito.Utils.scoped_mode_enabled?() do
            :ignored
          else
            Logs.create_http_log(attributes)
          end
      end
    end
  rescue
    error ->
      Logger.warning("Could not persist malformed HTTP request: #{Exception.message(error)}")
      {:error, error}
  end

  defp attributes(request, metadata) do
    reason = Map.get(metadata, :error) || Map.get(metadata, :reason) || :unknown

    %{
      ip: request |> Map.get(:peer) |> ip(),
      method: request |> Map.get(:method) |> safe_text("<unparsed>"),
      url: url(request),
      headers: headers(request),
      body: "",
      body_encoding: "utf-8",
      error: error_message(reason),
      params: %{}
    }
  end

  defp error_message({_category, _reason, message}) when is_binary(message), do: message

  defp error_message({_category, _reason, message}) when is_atom(message),
    do: Atom.to_string(message)

  defp error_message({_category, _reason, message}) when is_list(message) do
    if List.ascii_printable?(message),
      do: List.to_string(message),
      else: inspect(message, limit: 20, printable_limit: 500)
  end

  defp error_message(reason), do: inspect(reason, limit: 20, printable_limit: 500)

  defp scope(%{url: "<unparsed>"}, _request), do: :global

  defp scope(%{url: url}, request) do
    path = url |> String.split("?", parts: 2) |> hd() |> String.trim_leading("/")

    case LoritoWeb.PublicController.get_workspace(path) do
      {:ok, workspace, _route} ->
        {:workspace, workspace}

      _ ->
        with host when is_binary(host) <- raw_header(request, "host"),
             subdomain when not is_nil(subdomain) <- LoritoWeb.Utils.get_subdomain(host),
             {:ok, project} <- Projects.get_project_by_subdomain(subdomain) do
          {:project, project}
        else
          _ -> :global
        end
    end
  end

  defp url(request) do
    case Map.get(request, :path) do
      nil ->
        "<unparsed>"

      path ->
        path = safe_text(path, "<unparsed>")

        case Map.get(request, :qs) do
          qs when is_binary(qs) and qs != "" -> path <> "?" <> safe_text(qs, "<invalid>")
          _ -> path
        end
    end
  end

  defp headers(request) do
    request
    |> Map.get(:headers, %{})
    |> Enum.reject(fn {name, value} -> value == "" or fly_header?(name) end)
    |> Enum.map(fn {name, value} ->
      [safe_text(name, "<invalid>"), safe_text(value, "<invalid>")]
    end)
  end

  defp fly_header?(name) when is_binary(name) do
    String.starts_with?(name, ["fly-", "x-forwarded-", "via", "x-request-start"])
  end

  defp fly_header?(_name), do: false

  defp internal_request?(request) do
    internal_path?(Map.get(request, :path)) or
      case raw_header(request, "cookie") do
        cookie when is_binary(cookie) -> String.contains?(cookie, "_lorito_key=")
        _ -> false
      end
  end

  defp internal_path?(path) when is_binary(path) do
    Enum.any?(["/_lorito", "/live", "/ash_ai"], fn prefix ->
      path == prefix or String.starts_with?(path, prefix <> "/")
    end)
  end

  defp internal_path?(_path), do: false

  defp raw_header(request, wanted_name) do
    request
    |> Map.get(:headers, %{})
    |> Enum.find_value(fn
      {name, value} when is_binary(name) ->
        if String.downcase(name) == wanted_name, do: value

      _ ->
        nil
    end)
  end

  defp ip({address, _port}), do: ip(address)

  defp ip(address) when is_tuple(address) do
    case :inet.ntoa(address) do
      {:error, _} -> "<unknown>"
      chars -> to_string(chars)
    end
  end

  defp ip(_address), do: "<unknown>"

  defp safe_text(value, _fallback) when is_binary(value) do
    if String.valid?(value) and :binary.match(value, <<0>>) == :nomatch do
      value
    else
      "base64:" <> Base.encode64(value)
    end
  end

  defp safe_text(nil, fallback), do: fallback
  defp safe_text(value, _fallback), do: inspect(value)
end
