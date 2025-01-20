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
          <input type="hidden" name="response[headers_sort][]" value={header_form.index} />
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
                  name="response[headers_drop][]"
                  value={header_form.index}
                  class="hidden"
                />
                <.icon name="hero-x-mark" class="w-5 h-5" />
              </label>
            </div>
          </div>
        </.inputs_for>

        <label class="block cursor-pointer">
          <input type="checkbox" name="response[headers_sort][]" class="hidden" />
          <.icon name="hero-plus-circle" class="w-5 h-5" /> add header
        </label>

        <input type="hidden" name="response[headers_drop][]" />

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
            <input type="hidden" name="response[placeholders_sort][]" value={placeholder_form.index} />
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
                    name="response[placeholders_drop][]"
                    value={placeholder_form.index}
                    class="hidden"
                  />
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </label>
              </div>
            </div>
          </.inputs_for>

          <label class="block cursor-pointer">
            <input type="checkbox" name="response[placeholders_sort][]" class="hidden" />
            <.icon name="hero-plus-circle" class="w-5 h-5" /> add placeholder
          </label>

          <input type="hidden" name="response[placeholders_drop][]" />
        </div>

        <:actions>
          <.button class="btn-primary" phx-disable-with="Saving...">Save Response</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{response: response} = assigns, socket) do
    changeset = Responses.change_response(response)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)
     |> assign(content_type_matches: [], body: response.body)}
  end

  @impl true
  def handle_event("validate", %{"_target" => ["live_monaco_editor", ""]}, socket) do
    # ignore change events from the editor field
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"response" => response_params}, socket) do
    changeset =
      socket.assigns.response
      |> Responses.change_response(response_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("set_editor_value", %{"value" => value}, socket) do
    {:noreply, assign(socket, body: value)}
  end

  def handle_event(
        "save",
        %{"response" => response_params},
        %{assigns: %{body: body}} = socket
      ) do
    response_params = Map.put(response_params, "body", body)
    save_response(socket, socket.assigns.action, response_params)
  end

  def handle_event(
        "suggest_content_type",
        %{"response" => %{"content_type" => search}},
        socket
      ) do
    matches = Responses.suggest_content_type(search)
    {:noreply, assign(socket, content_type_matches: matches)}
  end

  defp save_response(socket, action, response_params) when action in [:edit, :edit_response] do
    case Responses.update_response(socket.assigns.response, response_params) do
      {:ok, response} ->
        notify_parent({:saved, response})

        {:noreply,
         socket
         |> put_flash(:info, "Response updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_response(socket, action, response_params)
       when action in [:new, :new_response] do
    workspace_or_template =
      Map.get(socket.assigns, :workspace) || Map.get(socket.assigns, :template)

    case Responses.create_response(response_params, workspace_or_template) do
      {:ok, response} ->
        notify_parent({:saved, response})

        {:noreply,
         socket
         |> put_flash(:info, "Response created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    assign(socket, :form, to_form(changeset))
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
