defmodule Lorito.RuntimeConfigTest do
  use ExUnit.Case, async: false

  setup do
    original_port = System.get_env("DNS_PORT")
    original_dir = System.get_env("TZDATA_DIR")
    original_database_url = System.get_env("DATABASE_URL")
    original_secret_key_base = System.get_env("SECRET_KEY_BASE")
    original_database_ssl_verify = System.get_env("DATABASE_SSL_VERIFY")
    original_database_ssl_ca_file = System.get_env("DATABASE_SSL_CA_FILE")

    on_exit(fn ->
      restore("DNS_PORT", original_port)
      restore("TZDATA_DIR", original_dir)
      restore("DATABASE_URL", original_database_url)
      restore("SECRET_KEY_BASE", original_secret_key_base)
      restore("DATABASE_SSL_VERIFY", original_database_ssl_verify)
      restore("DATABASE_SSL_CA_FILE", original_database_ssl_ca_file)
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

  test "production database TLS verifies certificates by default and when enabled explicitly" do
    set_production_env()

    for value <- [nil, "true"] do
      restore("DATABASE_SSL_VERIFY", value)
      repo = read_config(:prod)[:lorito][Lorito.Repo]

      assert repo[:ssl] == true
      refute Keyword.has_key?(repo, :ssl_opts)
    end
  end

  test "production database TLS verification can be disabled explicitly" do
    set_production_env()
    System.put_env("DATABASE_SSL_VERIFY", "false")

    repo = read_config(:prod)[:lorito][Lorito.Repo]

    assert repo[:ssl] == [verify: :verify_none]
    refute Keyword.has_key?(repo, :ssl_opts)
  end

  test "production database TLS verifies with a configured CA file" do
    set_production_env()
    ca_file = "/path/to/ca-certificate-mounted-at-runtime.pem"

    for verify <- [nil, "true"] do
      restore("DATABASE_SSL_VERIFY", verify)
      System.put_env("DATABASE_SSL_CA_FILE", ca_file)

      repo = read_config(:prod)[:lorito][Lorito.Repo]

      assert repo[:ssl] == [cacertfile: ca_file]
      refute Keyword.has_key?(repo, :ssl_opts)
    end
  end

  test "production rejects a CA file when TLS verification is disabled" do
    set_production_env()
    System.put_env("DATABASE_SSL_VERIFY", "false")
    System.put_env("DATABASE_SSL_CA_FILE", "/tmp/ca.pem")

    assert_raise ArgumentError,
                 "DATABASE_SSL_CA_FILE cannot be used when verification is disabled",
                 fn -> read_config(:prod) end
  end

  test "production rejects a blank CA file path" do
    set_production_env()

    for path <- ["", " "] do
      System.put_env("DATABASE_SSL_CA_FILE", path)

      assert_raise ArgumentError, "DATABASE_SSL_CA_FILE must not be empty", fn ->
        read_config(:prod)
      end
    end
  end

  test "database URL cannot disable TLS or override its options" do
    set_production_env()

    for query <- [
          "ssl=false",
          "ssl=FALSE",
          "ssl_opts=verify_none",
          "ssl=true&ssl=false",
          "s%73l=false"
        ] do
      System.put_env(
        "DATABASE_URL",
        "postgresql://postgres:postgres@db.example:5432/app?" <> query
      )

      assert_raise ArgumentError, "DATABASE_URL must not override database TLS options", fn ->
        read_config(:prod)
      end
    end
  end

  test "database URL can retain an explicit TLS requirement" do
    set_production_env()

    System.put_env(
      "DATABASE_URL",
      "postgresql://postgres:postgres@db.example:5432/app?ssl=true"
    )

    assert read_config(:prod)[:lorito][Lorito.Repo][:ssl] == true
  end

  test "invalid production database TLS verification settings fail at startup" do
    set_production_env()

    for value <- ["", "FALSE", "0", "yes"] do
      System.put_env("DATABASE_SSL_VERIFY", value)

      assert_raise ArgumentError, "DATABASE_SSL_VERIFY must be true or false", fn ->
        read_config(:prod)
      end
    end
  end

  defp set_production_env do
    System.put_env("DATABASE_URL", "postgresql://postgres:postgres@db.example:5432/app")
    System.put_env("SECRET_KEY_BASE", String.duplicate("a", 64))
    System.delete_env("DATABASE_SSL_CA_FILE")
  end

  defp read_config, do: read_config(:test)
  defp read_config(env), do: Config.Reader.read!("config/runtime.exs", env: env)
  defp restore(name, nil), do: System.delete_env(name)
  defp restore(name, value), do: System.put_env(name, value)
end
