defmodule AntlVaultAuth.TokensTest do
  use ExUnit.Case, async: true

  @valid_response %{auth: %{client_token: "token", lease_duration: 60}}

  @role_id_1 "role_id_1"
  @secret_id_1 "secret_id_1"

  setup do
    AntlVaultAuth.Tokens.init()
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  test "auth", %{bypass: bypass} do
    options = vault_options(bypass.port)
    creds = %{role_id: @role_id_1, secret_id: @secret_id_1}
    url = options[:host]

    expect_once_login(bypass, @role_id_1, @secret_id_1)

    # First auth call
    assert match? {:ok, %Vault{
      auth: Vault.Auth.Approle,
      auth_path: nil,
      credentials: %{role_id: @role_id_1, secret_id: "secret_id_1"},
      engine: Vault.Engine.KVV1,
      host: ^url,
      http: Vault.HTTP.Tesla,
      http_options: [],
      json: Jason,
      token: "token",
    }}, AntlVaultAuth.Tokens.auth(Vault.new(options), creds)

    # Second auth call.
    # Token must be read from the cache.
    # There must be no an HTTP request.
    assert {:ok, _vault} = AntlVaultAuth.Tokens.auth(Vault.new(options), creds)
  end

  test "renew", %{bypass: bypass} do
    options = vault_options(bypass.port)
    creds = %{role_id: @role_id_1, secret_id: @secret_id_1}
    url = options[:host]

    expect_once_login(bypass, @role_id_1, @secret_id_1)

    # First auth call
    assert match? {:ok, %Vault{
      auth: Vault.Auth.Approle,
      auth_path: nil,
      credentials: %{role_id: @role_id_1, secret_id: @secret_id_1},
      engine: Vault.Engine.KVV1,
      host: ^url,
      http: Vault.HTTP.Tesla,
      http_options: [],
      json: Jason,
      token: "token",
    }}, AntlVaultAuth.Tokens.auth(Vault.new(options), creds)

    # Renew allowed 10 seconds before token will be expired.
    # There should be no a HTTP request, because there is more then 10 seconds to the token expiration
    AntlVaultAuth.Tokens.renew(10)

    expect_once_login(bypass, @role_id_1, @secret_id_1)

    # Renew allowed 70 seconds before token will be expired
    # There must be a HTTP request, because there is less then 70 seconds to the token expiration
    AntlVaultAuth.Tokens.renew(70)
  end

  defp expect_once_login(bypass, role_id, secret_id) do
    Bypass.expect_once(bypass, "POST", "/v1/auth/approle/login", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert Jason.decode!(body) == %{"role_id" => role_id, "secret_id" => secret_id}

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, Jason.encode!(@valid_response))
    end)
  end

  defp vault_options(port) do
    [
      host: endpoint_url(port),
      json: Jason,
      engine: Vault.Engine.KVV1,
      auth: Vault.Auth.Approle,
      http: Vault.HTTP.Tesla,
    ]
  end

  defp endpoint_url(port), do: "http://localhost:#{port}"

end
