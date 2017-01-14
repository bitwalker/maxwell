defmodule RetryTest do
  use ExUnit.Case, async: false
  alias Maxwell.Conn

  defmodule LaggyAdapter do
    def start_link, do: Agent.start_link(fn -> 0 end, name: __MODULE__)

    def call(%{path: path} = conn) do
      conn = %{conn | state: :sent}
      Agent.get_and_update __MODULE__, fn retries ->
        response = case path do
          "/ok"                     -> {:ok, %{conn | status: 200, resp_body: "ok"}}
          "/maybe" when retries < 5 -> {:error, :econnrefused, conn}
          "/maybe"                  -> {:ok, %{conn | status: 200, resp_body: "maybe"}}
          "/nope"                   -> {:error, :econnrefused, conn}
          _                         -> {:error, :something_wrong, conn}
        end

        {response, retries + 1}
      end
    end
  end


  defmodule Client do
    use Maxwell.Builder

    middleware Maxwell.Middleware.Retry, delay: 10, max_retries: 10

    adapter LaggyAdapter
  end

  setup do
    {:ok, _} = LaggyAdapter.start_link
    :ok
  end

  test "pass on successful request" do
    assert Conn.put_path("/ok") |> Client.get! |> Conn.get_resp_body() == "ok"
  end

  test "don't rery if error is not econnrefused" do
    assert_raise Maxwell.Error, fn -> Conn.put_path("/other") |> Client.get! end
  end

  test "pass after retry" do
    assert Conn.put_path("/maybe") |> Client.get! |> Conn.get_resp_body() == "maybe"
  end

  test "raise error if max_retries is exceeded" do
    assert_raise Maxwell.Error, fn -> Conn.put_path("/nope") |> Client.get! end
  end

end
