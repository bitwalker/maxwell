defmodule Maxwell do
  @moduledoc  """
  This module defines a simplified HTTP client API for use in cases where
  defining a wrapper module is too heavy.

  ### Example Usage

      iex> Maxwell.get!("http://httpbin.org/ip")
      ...> |> Maxwell.Conn.get_resp_body()
      ...> |> Poison.decode!
      %{"origin" => "127.0.0.1}

      iex> Maxwell.get!("http://httpbin.org/ip", %{"user-agent" => "zhongwencool"})
      ...> |> Maxwell.Conn.get_resp_body()
      ...> |> Poison.decode!
      %{"origin" => "127.0.0.1}

      iex> Maxwell.post!("http://httpbin.org/post", %{"user-agent" => "zhongwencool"}, Poison.encode!(%{}))
      ...> |> Maxwell.Conn.get_resp_body()
      ...> |> Poison.decode!
      %{}

      iex> conn = Maxwell.Conn.new("http://httpbin.org/post")
      ...> |> Maxwell.Conn.put_req_headers(%{"content-type" => "application/json"})
      ...> |> Maxwell.Conn.put_req_body(Poison.encode!(%{}))
      ...> |> Maxwell.post!
      ...> |> Maxwell.Conn.get_resp_body()
      ...> |> Poison.decode!
      %{}
  """
  @methods_without_body [{:get!, :get}, {:head!, :head}, {:delete!, :delete}, {:trace!, :trace}, {:options!, :options}]
  @methods_with_body [{:post!, :post}, {:put!, :put}, {:patch!, :patch}]
  quoted = for {method, method_bang} <- @methods_without_body do
    quote do
      @doc """
      Executes a #{unquote(method) |> to_string() |> String.upcase} request.

      This function accepts either a url string or a `Maxwell.Conn.t` struct.
      It returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`
      """
      @spec unquote(method)(String.t | Maxwell.Conn.t) :: {:ok, Maxwell.Conn.t} | {:error, term(), Maxwell.Conn.t}
      def unquote(method)(%Maxwell.Conn{req_body: nil} = conn) do
        request(conn)
      end
      def unquote(method)(%Maxwell.Conn{} = conn) do
        raise Maxwell.Error, {__MODULE__, "#{unquote(method)}/1 should not contain a body", conn};
      end
      def unquote(method)(url) when is_binary(url) do
        request(Maxwell.Conn.new(url))
      end

      @doc """
      Executes a #{unquote(method) |> to_string() |> String.upcase} request, using the
      provided url string and headers.

      The headers must be provided as a map.

      This function returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`
      """
      @spec unquote(method)(String.t, map()) :: {:ok, Maxwell.Conn.t} | {:error, term(), Maxwell.Conn.t}
      def unquote(method)(url, headers) when is_map(headers) do
        Maxwell.Conn.new(url)
        |> Maxwell.Conn.put_req_headers(headers)
        |> request()
      end

      @doc """
      Same as #{unquote(method)}/1, but returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` if the request
      fails, or the response status code is not in the 2xx range.
      """
      @spec unquote(method_bang)(String.t | Maxwell.Conn.t) :: Maxwell.Conn.t | no_return
      def unquote(method_bang)(conn) do
        case unquote(method_bang)(conn) do
          {:ok, %Maxwell.Conn{status: status} = conn} when status in 200..299 ->
            conn
          {:ok, conn} ->
            raise Maxwell.Error, {__MODULE__, :response_status_not_match, conn}
          {:error, reason, conn} ->
            raise Maxwell.Error, {__MODULE__, reason, conn}
        end
      end

      @doc """
      Same as #{unquote(method)}/2, but returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` if the request
      fails, or the response status code is not in the 2xx range.
      """
      @spec unquote(method_bang)(String.t, map()) :: Maxwell.Conn.t | no_return
      def unquote(method_bang)(url, headers) when is_map(headers) do
        Maxwell.Conn.new(url)
        |> Maxwell.Conn.put_req_headers(headers)
        |> unquote(method_bang)()
      end
    end
  end
  Module.eval_quoted(__ENV__, quoted)

  quoted = for {method, method_bang} <- @methods_with_body do
    quote location: :keep do
      @doc """
      Executes a #{unquote(method) |> to_string |> String.upcase} request.

      Returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`
      """
      @spec unquote(method)(Maxwell.Conn.t) :: {:ok, Maxwell.Conn.t} | {:error, term(), Maxwell.Conn.t}
      def unquote(method)(%Maxwell.Conn{} = conn) do
        request(conn)
      end

      @doc """
      Executes a #{unquote(method) |> to_string |> String.upcase} request, using the
      provided url, headers, and body.

      The headers must be a map.

      Returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`
      """
      @spec unquote(method)(String.t, map(), term()) :: {:ok, Maxwell.Conn.t} | {:error, term(), Maxwell.Conn.t}
      def unquote(method)(url, headers, body) when is_map(headers) do
        Maxwell.Conn.new(url)
        |> Maxwell.Conn.put_req_headers(headers)
        |> Maxwell.Conn.put_req_body(body)
        |> request()
      end

      @doc """
      Same as #{unquote(method)}/1, but returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` if the request fails
      or the response status code is not in the 2xx range.
      """
      @spec unquote(method_bang)(Maxwell.Conn.t) :: Maxwell.Conn.t | no_return
      def unquote(method_bang)(conn) do
        case unquote(method_bang)(conn) do
          {:ok, %Maxwell.Conn{status: status} = conn} when status in 200..299 ->
            conn
          {:ok, conn} ->
            raise Maxwell.Error, {__MODULE__, :response_status_not_match, conn}
          {:error, reason, conn} ->
            raise Maxwell.Error, {__MODULE__, reason, conn}
        end
      end

      @doc """
      Same as #{unquote(method)}/3, but returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` if the request fails
      or the response status code is not in the 2xx range.
      """
      @spec unquote(method_bang)(String.t, map(), term()) :: Maxwell.Conn.t | no_return
      def unquote(method_bang)(url, headers, body) when is_map(headers) do
        Maxwell.Conn.new(url)
        |> Maxwell.Conn.put_req_headers(headers)
        |> Maxwell.Conn.put_req_body(body)
        |> unquote(method_bang)()
      end
    end
  end
  Module.eval_quoted(__ENV__, quoted)

  defp request(%Maxwell.Conn{} = conn) do
    Maxwell.Builder.Util.default_adapter().call(conn)
  end
end
