defmodule Lorito.RuntimeConfigTest do
  use ExUnit.Case, async: false

  setup do
    original_port = System.get_env("DNS_PORT")
    original_dir = System.get_env("TZDATA_DIR")

    on_exit(fn ->
      restore("DNS_PORT", original_port)
      restore("TZDATA_DIR", original_dir)
    end)

    :ok
  end

  test "DNS defaults to 53 outside Docker and accepts unprivileged ports" do
    System.delete_env("DNS_PORT")
    assert read_config()[:lorito][:dns_port] == 53

    for port <- ["1", "4053", "65535"] do
      System.put_env("DNS_PORT", port)
      assert read_config()[:lorito][:dns_port] == String.to_integer(port)
    end
  end

  test "invalid DNS ports fail at startup" do
    for port <- ["", "0", "-1", "65536", "4053abc", "53.0"] do
      System.put_env("DNS_PORT", port)

      assert_raise ArgumentError, "DNS_PORT must be an integer between 1 and 65535", fn ->
        read_config()
      end
    end
  end

  test "timezone updates use the configured writable directory" do
    System.put_env("DNS_PORT", "4053")
    System.put_env("TZDATA_DIR", "/var/lib/lorito/tzdata")
    assert read_config()[:tzdata][:data_dir] == "/var/lib/lorito/tzdata"
  end

  defp read_config, do: Config.Reader.read!("config/runtime.exs", env: :test)
  defp restore(name, nil), do: System.delete_env(name)
  defp restore(name, value), do: System.put_env(name, value)
end
