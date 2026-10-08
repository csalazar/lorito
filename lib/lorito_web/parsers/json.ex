defmodule LoritoWeb.Parsers.JSON do
  @moduledoc false
  @behaviour Plug.Parsers

  @impl true
  def init(opts) do
    {decoder, opts} = Keyword.pop(opts, :json_decoder)
    {body_reader, opts} = Keyword.pop(opts, :body_reader, {Plug.Conn, :read_body, []})
    {{body_reader, validate_decoder!(decoder)}, opts}
  end

  @impl true
  def parse(conn, "application", subtype, _headers, {{{mod, fun, args}, decoder}, opts}) do
    if subtype == "json" or String.ends_with?(subtype, "+json") do
      apply(mod, fun, [conn, opts | args])
      |> decode(decoder, opts)
    else
      {:next, conn}
    end
  end

  def parse(conn, _type, _subtype, _headers, _opts), do: {:next, conn}

  defp decode({:ok, "", conn}, _decoder, _opts), do: {:ok, %{}, conn}

  defp decode({:ok, body, conn}, {module, fun, args}, opts) do
    nest_all? = Keyword.get(opts, :nest_all_json, false)

    case safe_decode(module, fun, body, args) do
      {:ok, terms} when is_map(terms) and not nest_all? -> {:ok, terms, conn}
      {:ok, terms} -> {:ok, %{"_json" => terms}, conn}
      :error -> {:ok, %{}, conn}
    end
  end

  defp decode({:more, _, conn}, _decoder, _opts), do: {:error, :too_large, conn}
  defp decode({:error, :timeout}, _decoder, _opts), do: raise(Plug.TimeoutError)
  defp decode({:error, _}, _decoder, _opts), do: raise(Plug.BadRequestError)

  defp safe_decode(module, fun, body, args) do
    {:ok, apply(module, fun, [body | args])}
  rescue
    _ -> :error
  end

  defp validate_decoder!(nil),
    do: raise(ArgumentError, "JSON parser expects a :json_decoder option")

  defp validate_decoder!({module, fun, args} = decoder)
       when is_atom(module) and is_atom(fun) and is_list(args) do
    if Code.ensure_compiled(module) == {:module, module} and
         function_exported?(module, fun, length(args) + 1) do
      decoder
    else
      raise ArgumentError, "invalid :json_decoder option: #{inspect(decoder)}"
    end
  end

  defp validate_decoder!(decoder) when is_atom(decoder) do
    validate_decoder!({decoder, :decode!, []})
  end

  defp validate_decoder!(decoder) do
    raise ArgumentError, "invalid :json_decoder option: #{inspect(decoder)}"
  end
end
