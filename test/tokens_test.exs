defmodule AntlVaultAuth.TokensTest do
  use ExUnit.Case, async: true

  @valid_response %{auth: %{client_token: "token", lease_duration: 60}}

  @role_id_1 "role_id_1"
  @secret_id_1 "secret_id_1"

  setup do
    AntlVaultAuth.Tokens.init()
    # /!\ You have to rollback the ets table before each test.

    bypass = Bypass.open()

    {:ok, bypass: bypass}
  end

  # These tests have to be in antl_vault_auth_test.exs since the function is now there.
  describe "auth/2" do
    test "when the cache contains an authenticated vault client for the credentials and the vault has the same options, returns the cached authenticated vault" do
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different host, authenticates to the vault and save the vault client",
         %{bypass: bypass_1} do
      bypass_2 = Bypass.open()

      vault_client_1 =
        Vault.new(
          auth: Vault.Auth.Approle,
          engine: Vault.Engine.KVV2,
          http: Vault.HTTP.Tesla,
          host: endpoint_url(bypass_1.port),
          json: Jason
        )

      vault_client_2 = Map.replace!(vault_client_1, :host, endpoint_url(bypass_2.port))

      credentials = %{role_id: "role_id", secret_id: "secret_id"}

      expect_once_login(bypass_1, credentials)
      expect_once_login(bypass_2, credentials)

      {:ok, authenticated_vault_client_1} = AntlVaultAuth.Tokens.auth(vault_client_1, credentials)

      assert {:ok, authenticated_vault_client_2} =
               AntlVaultAuth.Tokens.auth(vault_client_2, credentials)

      assert authenticated_vault_client_2.token != authenticated_vault_client_1.token

      Bypass.down(bypass_2)
    end

    test "when the cache contains an authenticated vault client for the credentials but with a different auth method, authenticates to the vault and save the vault client",
         %{bypass: _bypass} do
    end

    test "when the cache does not contains an authenticated vault client for the credentials, authenticates to the vault and save the  vault client" do
    end
  end

  test "auth/2", %{bypass: bypass} do
    options = vault_options(bypass.port)
    creds = %{role_id: @role_id_1, secret_id: @secret_id_1}
    url = options[:host]

    expect_once_login(bypass, creds)

    # First auth call
    assert match?(
             {:ok,
              %Vault{
                auth: Vault.Auth.Approle,
                auth_path: nil,
                credentials: %{role_id: @role_id_1, secret_id: "secret_id_1"},
                engine: Vault.Engine.KVV1,
                host: ^url,
                http: Vault.HTTP.Tesla,
                http_options: [],
                json: Jason,
                token: "token"
              }},
             AntlVaultAuth.Tokens.auth(Vault.new(options), creds)
           )

    # Second auth call.
    # Token must be read from the cache.
    # There must be no an HTTP request.
    assert {:ok, _vault} = AntlVaultAuth.Tokens.auth(Vault.new(options), creds)
  end

  test "renew_all/1", %{bypass: bypass} do
    options = vault_options(bypass.port)
    creds = %{role_id: @role_id_1, secret_id: @secret_id_1}
    url = options[:host]

    expect_once_login(bypass, creds)

    # First auth call
    assert match?(
             {:ok,
              %Vault{
                auth: Vault.Auth.Approle,
                auth_path: nil,
                credentials: %{role_id: @role_id_1, secret_id: @secret_id_1},
                engine: Vault.Engine.KVV1,
                host: ^url,
                http: Vault.HTTP.Tesla,
                http_options: [],
                json: Jason,
                token: "token"
              }},
             AntlVaultAuth.Tokens.auth(Vault.new(options), creds)
           )

    # Renew allowed 10 seconds before token will be expired.
    # There should be no a HTTP request, because there is more then 10 seconds to the token expiration
    AntlVaultAuth.Tokens.renew_all(10)

    expect_once_login(bypass, creds)

    # Renew allowed 70 seconds before token will be expired
    # There must be a HTTP request, because there is less then 70 seconds to the token expiration
    AntlVaultAuth.Tokens.renew_all(70)
  end

  defp expect_once_login(bypass, %{role_id: role_id, secret_id: secret_id}) do
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
      http: Vault.HTTP.Tesla
    ]
  end

  defp endpoint_url(port), do: "http://localhost:#{port}"
end
