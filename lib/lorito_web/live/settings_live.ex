defmodule LoritoWeb.SettingsLive do
  use LoritoWeb, :live_view

  alias Lorito.Settings

  @dns_keys ~w(dns_enabled dns_domain dns_ipv4_address dns_ipv6_address)

  @impl true
  def mount(_params, _session, socket) do
    setting = Settings.get_settings!()
    data = setting.data

    form_data =
      Map.new(@dns_keys, fn
        "dns_enabled" = key -> {key, Map.get(data, key, false)}
        key -> {key, Map.get(data, key, "")}
      end)

    {:ok,
     assign(socket,
       setting: setting,
       form: to_form(form_data, as: "dns"),
       dns_enabled: Map.get(data, "dns_enabled", false)
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      App Settings
    </.header>

    <div class="divider divider-accent divider-start pt-8">DNS</div>

    <.simple_form for={@form} phx-submit="save" phx-change="validate">
      <.input field={@form[:dns_enabled]} type="checkbox" label="DNS server" />
      <.input field={@form[:dns_domain]} type="text" label="Domain" disabled={not @dns_enabled} />
      <.input field={@form[:dns_ipv4_address]} type="text" label="IPv4 address" disabled={not @dns_enabled} />
      <.input field={@form[:dns_ipv6_address]} type="text" label="IPv6 address" disabled={not @dns_enabled} />
      <:actions>
        <.button class="btn btn-primary btn-sm" phx-disable-with="Saving...">Save</.button>
      </:actions>
    </.simple_form>
    """
  end

  @required_when_enabled ~w(dns_domain dns_ipv4_address dns_ipv6_address)

  @impl true
  def handle_event("validate", %{"dns" => params}, socket) do
    merged = Map.merge(socket.assigns.form.source, params)
    errors = validate_params(merged)
    dns_enabled = merged["dns_enabled"] in [true, "true"]

    {:noreply,
     assign(socket,
       form: to_form(merged, as: "dns", errors: errors),
       dns_enabled: dns_enabled
     )}
  end

  @impl true
  def handle_event("save", %{"dns" => params}, socket) do
    merged = Map.merge(socket.assigns.form.source, params)
    errors = validate_params(merged)

    if errors != [] do
      {:noreply, assign(socket, :form, to_form(merged, as: "dns", errors: errors))}
    else
      new_data =
        Map.new(@dns_keys, fn
          "dns_enabled" = k -> {k, merged[k] in [true, "true"]}
          k -> {k, merged[k] || ""}
        end)

      case Settings.update_settings(socket.assigns.setting, %{data: new_data},
             actor: socket.assigns.current_user
           ) do
        {:ok, updated_setting} ->
          if updated_setting.data["dns_enabled"],
            do: Lorito.DnsServer.enable(),
            else: Lorito.DnsServer.disable()

          {:noreply,
           socket
           |> put_flash(:info, "Settings saved")
           |> assign(:setting, updated_setting)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not save settings")}
      end
    end
  end

  defp validate_params(%{"dns_enabled" => enabled} = params) when enabled in [true, "true"] do
    Enum.flat_map(@required_when_enabled, fn key ->
      if params[key] in [nil, ""],
        do: [{String.to_atom(key), {"can't be blank when DNS is enabled", []}}],
        else: []
    end)
  end

  defp validate_params(_params), do: []
end
