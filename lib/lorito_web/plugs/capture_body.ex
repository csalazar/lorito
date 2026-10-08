defmodule LoritoWeb.Plugs.CaptureBody do
  @moduledoc false
  @behaviour Plug

  alias __MODULE__.Adapter

  @read_length 64_000
  @read_timeout 15_000
  @state_key {__MODULE__, :adapter_state}

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{path_info: [path | _]} = conn, _opts)
      when path in ["_lorito", "live", "ash_ai"] do
    conn
  end

  def call(%Plug.Conn{adapter: {adapter, state}} = conn, _opts) do
    wrapped_state = {adapter, state, {[], false}}
    remember(wrapped_state)
    %{conn | adapter: {Adapter, wrapped_state}}
  end

  def unwrap(%Plug.Conn{adapter: {Adapter, _}} = conn) do
    {adapter, state, _capture} = current_state(conn)
    Process.delete(@state_key)
    %{conn | adapter: {adapter, state}}
  end

  def unwrap(conn), do: conn

  def finish(%Plug.Conn{adapter: {Adapter, {_, _, {_, true}}}} = conn), do: {:ok, conn}

  def finish(%Plug.Conn{adapter: {Adapter, _}} = conn) do
    drain(conn)
  end

  def finish(conn), do: {:ok, conn}

  @doc false
  def recover(%Plug.Conn{adapter: {Adapter, _}} = conn) do
    %{conn | adapter: {Adapter, current_state(conn)}}
  end

  def recover(conn), do: conn

  @doc false
  def remember(state) do
    Process.put(@state_key, state)
    state
  end

  defp drain(conn) do
    case Plug.Conn.read_body(conn,
           length: @read_length,
           read_length: @read_length,
           read_timeout: @read_timeout
         ) do
      {:ok, _, conn} -> {:ok, conn}
      {:more, _, conn} -> drain(conn)
      {:error, reason} -> {:read_error, reason, conn}
    end
  end

  def captured_body(%Plug.Conn{adapter: {Adapter, _}} = conn) do
    {_, _, {parts, _done?}} = current_state(conn)
    parts |> Enum.reverse() |> IO.iodata_to_binary()
  end

  def captured_body(_conn), do: ""

  defp current_state(%Plug.Conn{adapter: {Adapter, state}}) do
    Process.get(@state_key, state)
  end

  defmodule Adapter do
    @moduledoc false
    @behaviour Plug.Conn.Adapter

    @impl true
    def read_req_body({adapter, state, capture}, opts) do
      case adapter.read_req_body(state, opts) do
        {result, data, state} when result in [:ok, :more] ->
          {parts, _done?} = capture
          parts = if data == "", do: parts, else: [data | parts]
          capture = {parts, result == :ok}
          wrapped_state = {adapter, state, capture}
          LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)

          {result, data, wrapped_state}

        {:error, reason} ->
          {:error, reason}
      end
    end

    @impl true
    def send_resp({adapter, state, capture}, status, headers, body) do
      {:ok, sent_body, state} = adapter.send_resp(state, status, headers, body)
      wrapped_state = {adapter, state, capture}
      LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
      {:ok, sent_body, wrapped_state}
    end

    @impl true
    def send_file({adapter, state, capture}, status, headers, file, offset, length) do
      {:ok, sent_body, state} = adapter.send_file(state, status, headers, file, offset, length)
      wrapped_state = {adapter, state, capture}
      LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
      {:ok, sent_body, wrapped_state}
    end

    @impl true
    def send_chunked({adapter, state, capture}, status, headers) do
      {:ok, sent_body, state} = adapter.send_chunked(state, status, headers)
      wrapped_state = {adapter, state, capture}
      LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
      {:ok, sent_body, wrapped_state}
    end

    @impl true
    def chunk({adapter, state, capture}, body) do
      case adapter.chunk(state, body) do
        {:ok, sent_body, state} ->
          wrapped_state = {adapter, state, capture}
          LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
          {:ok, sent_body, wrapped_state}

        other ->
          other
      end
    end

    @impl true
    def inform({adapter, state, capture}, status, headers) do
      case adapter.inform(state, status, headers) do
        {:ok, state} ->
          wrapped_state = {adapter, state, capture}
          LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
          {:ok, wrapped_state}

        other ->
          other
      end
    end

    @impl true
    def upgrade({adapter, state, capture}, protocol, opts) do
      case adapter.upgrade(state, protocol, opts) do
        {:ok, state} ->
          wrapped_state = {adapter, state, capture}
          LoritoWeb.Plugs.CaptureBody.remember(wrapped_state)
          {:ok, wrapped_state}

        other ->
          other
      end
    end

    @impl true
    def get_peer_data({adapter, state, _}), do: adapter.get_peer_data(state)
    @impl true
    def get_sock_data({adapter, state, _}), do: adapter.get_sock_data(state)
    @impl true
    def get_ssl_data({adapter, state, _}), do: adapter.get_ssl_data(state)
    @impl true
    def get_http_protocol({adapter, state, _}), do: adapter.get_http_protocol(state)
    @impl true
    def push({adapter, state, _}, path, headers), do: adapter.push(state, path, headers)
  end
end
