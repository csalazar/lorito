defmodule Lorito.Templates do
  use Ash.Domain,
    otp_app: :lorito,
    extensions: [AshPhoenix]

  resources do
    resource Lorito.Templates.Template do
      define :list_templates, action: :read
      define :create_template, action: :create
      define :delete_template, action: :destroy
      define :update_template, action: :update
      define :get_template_by_id, action: :get_template_by_id, get_by: [:id]
    end
  end
end
