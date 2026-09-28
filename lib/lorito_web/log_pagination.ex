defmodule LoritoWeb.LogPagination do
  use Phoenix.Component
  import Phoenix.LiveView

  def load(socket, params, uri, filters) do
    opts =
      cond do
        is_binary(params["after"]) -> [limit: 50, after: params["after"]]
        is_binary(params["before"]) -> [limit: 50, before: params["before"]]
        true -> [limit: 50]
      end

    socket
    |> assign(:log_path, URI.parse(uri).path)
    |> assign(:log_query, Map.take(params, ["scoped_logs"]))
    |> assign(:log_filters, filters)
    |> assign(:log_page_opts, opts)
    |> assign(:new_logs_available, false)
    |> reload()
  end

  def reload(socket) do
    case Lorito.Logs.page_logs(socket.assigns.log_filters, page: socket.assigns.log_page_opts) do
      {:ok, %{before: before, more?: false}} when not is_nil(before) ->
        socket
        |> assign(:log_page_opts, limit: 50)
        |> reload()
        |> push_patch(to: url(socket.assigns, []))

      {:ok, page} ->
        socket |> assign(:log_page, page) |> stream(:logs, page.results, reset: true)

      {:error, error} ->
        if socket.assigns.log_page_opts == [limit: 50] do
          raise error
        else
          socket
          |> assign(:log_page_opts, limit: 50)
          |> reload()
          |> put_flash(:error, "Could not load that log page. Showing the latest logs.")
          |> push_patch(to: url(socket.assigns, []))
        end
    end
  end

  def created(socket, log) do
    filters = socket.assigns.log_filters

    matches? =
      (not Map.get(filters, :scoped_logs, false) or not is_nil(log.project_id)) and
        (is_nil(filters[:workspace_id]) or filters[:workspace_id] == log.workspace_id) and
        (is_nil(filters[:project_id]) or filters[:project_id] == log.project_id)

    cond do
      not matches? -> socket
      socket.assigns.log_page_opts == [limit: 50] -> reload(socket)
      true -> assign(socket, :new_logs_available, true)
    end
  end

  def url(assigns, cursor) do
    query = Map.merge(assigns.log_query, Map.new(cursor))
    assigns.log_path <> if(map_size(query) == 0, do: "", else: "?" <> URI.encode_query(query))
  end

  def controls(assigns) do
    page = assigns.log_page
    first = List.first(page.results)
    last = List.last(page.results)
    before? = not is_nil(page.before)
    historical? = not is_nil(page.after) or before?

    assigns =
      assigns
      |> assign(:newer, historical?)
      |> assign(:older, last && if(before?, do: true, else: page.more?))
      |> assign(:first_cursor, first && first.__metadata__.keyset)
      |> assign(:last_cursor, last && last.__metadata__.keyset)

    ~H"""
    <nav id="log-pagination" aria-label="Log pagination" class="flex items-center gap-3 py-4">
      <.link :if={@older} id="logs-older" patch={url(assigns, after: @last_cursor)} class="btn btn-sm">Older</.link>
      <button :if={!@older} id="logs-older" type="button" disabled class="btn btn-sm">Older</button>
      <.link
        :if={@newer}
        id="logs-newer"
        patch={url(assigns, if(@first_cursor, do: [before: @first_cursor], else: []))}
        class="btn btn-sm"
      >Newer</.link>
      <span :if={@new_logs_available} class="text-sm">New logs available</span>
      <span :if={@log_page.results == []} class="text-sm">No logs on this page.</span>
    </nav>
    """
  end
end
