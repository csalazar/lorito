defmodule Lorito.Utils do
  def scoped_mode_enabled? do
    case Lorito.Settings.get_settings() do
      {:ok, setting} -> Map.get(setting.data, "scoped_mode", false)
      _ -> false
    end
  end
end
