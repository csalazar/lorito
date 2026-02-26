defmodule LoritoWeb.ResponseLive.FormComponent do
  use LoritoWeb, :live_component

  alias Lorito.Responses

  @impl true
  def render(assigns) do
    assigns = assign(assigns, object: Map.get(assigns, :workspace, Map.get(assigns, :template)))

    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Use this form to manage response records in your database.</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="response-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:route]} type="text" label="Route" />
        <div class="flex">
          <.input
            type="select"
            field={@form[:status]}
            label="Status"
            options={
              Enum.map(Responses.list_http_codes(), fn {code, message} ->
                [key: "#{code} - #{message}", value: code]
              end)
            }
          />
          <.input
            field={@form[:content_type]}
            type="text"
            label="Content-Type"
            phx-change="suggest_content_type"
            list="content-type-matches"
          />

          <datalist id="content-type-matches">
            <option :for={match <- @content_type_matches} value={match}>
              {match}
            </option>
          </datalist>
        </div>
        <.input field={@form[:delay]} type="number" label="Delay (in seconds)" class="small" />

        <label class="block text-sm font-semibold leading-6 text-zinc-800 dark:text-base-content">
          Headers
        </label>
        <.inputs_for :let={header_form} field={@form[:headers]}>
          <div class="flex flex-row space-x-4">
            <div class="w-1/4">
              <.input type="text" field={header_form[:name]} label="Name" class="w-3/12" />
            </div>
            <div class="w-full">
              <.input type="text" field={header_form[:value]} label="Value" />
            </div>
            <div class="w-1/12">
              <label>
                <input
                  type="checkbox"
                  name={"#{@form.name}[_drop_headers][]"}
                  value={header_form.index}
                  class="hidden"
                />

                <.icon name="hero-x-mark" class="w-5 h-5" />
              </label>
            </div>
          </div>
        </.inputs_for>

        <label>
          <input
            type="checkbox"
            name={"#{@form.name}[_add_headers]"}
            value="end"
            class="hidden"
          />
          <.icon name="hero-plus-circle" class="w-5 h-5" /> add header
        </label>

        <label class="block text-sm font-semibold leading-6 text-zinc-800 dark:text-base-content">
          Body
        </label>
        <LiveMonacoEditor.code_editor
          value={@form[:body].value}
          change="set_editor_value"
          target={@myself}
        />

        <div :if={Enum.count(@object.responses) > 0} id="placeholders_section">
          <label class="block text-sm font-semibold leading-6 text-zinc-800">Placeholders</label>
          <.inputs_for :let={placeholder_form} field={@form[:placeholders]}>
            <div class="flex flex-row space-x-4">
              <div class="w-1/4">
                <.input type="text" field={placeholder_form[:icon]} label="Icon" class="w-3/12" />
              </div>
              <div class="w-full">
                <.input
                  type="select"
                  field={placeholder_form[:value]}
                  options={
                    for %{id: id, route: route} <- @object.responses, id != @response.id do
                      {route, id}
                    end
                  }
                  label="Value"
                  prompt="Select a response .."
                />
              </div>
              <div class="w-1/12">
                <label>
                  <input
                    type="checkbox"
                    name={"#{@form.name}[_drop_placeholders][]"}
                    value={placeholder_form.index}
                    class="hidden"
                  />

                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </label>
              </div>
            </div>
          </.inputs_for>

          <label>
            <input
              type="checkbox"
              name={"#{@form.name}[_add_placeholders]"}
              value="end"
              class="hidden"
            />
            <.icon name="hero-plus-circle" class="w-5 h-5" /> add placeholder
          </label>
        </div>

        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Response</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def get_form(%{template: template, current_user: current_user}) do
    Responses.form_to_create_response_for_template(template.id, actor: current_user)
  end

  def get_form(%{workspace: workspace, current_user: current_user}) do
    Responses.form_to_create_response_for_workspace(workspace.id, actor: current_user)
  end

  @impl true
  def update(%{action: action} = assigns, socket) when action in [:new, :new_response] do
    form = get_form(assigns)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(content_type_matches: [], body: "")
     |> assign(form: to_form(form))}
  end

  @impl true
  def update(%{action: action, response: response} = assigns, socket)
      when action in [:edit, :edit_response] do
    form = Responses.form_to_update_response(response)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(content_type_matches: [], body: response.body)
     |> assign(form: to_form(form))}
  end

  @impl true
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"form" => form_data}, %{assigns: %{body: body}} = socket) do
    form_data = Map.put(form_data, "body", body)

    case AshPhoenix.Form.submit(socket.assigns.form, params: form_data) do
      {:ok, response} ->
        notify_parent({:saved, response})

        socket =
          socket
          |> put_flash(:info, "Response saved successfully")
          |> push_patch(to: socket.assigns.patch)

        {:noreply, socket}

      {:error, form} ->
        socket =
          socket
          |> put_flash(:error, "Could not save response data")
          |> assign(:form, form)

        {:noreply, socket}
    end
  end

  def handle_event("set_editor_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, body: value)}
  end

  def handle_event(
        "suggest_content_type",
        %{"form" => %{"content_type" => search}},
        socket
      ) do
    matches = Responses.suggest_content_type(search)
    {:noreply, assign(socket, content_type_matches: matches)}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
