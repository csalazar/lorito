defmodule Lorito.Utils.HttpClient.Middleware.SafeURL do
  @behaviour Tesla.Middleware

  @impl true
  def call(env, next, opts) do
    with :ok <- SafeURL.validate(env.url, opts), do: Tesla.run(env, next)
  end
end

defmodule Lorito.Utils.HttpClient do
  use Tesla

  plug Tesla.Middleware.JSON
  plug Lorito.Utils.HttpClient.Middleware.SafeURL
end
