defmodule Maxwell.Builder do
  @moduledoc """
  This module is used for generating API wrapper modules.

  You inject the HTTP client behaviour into a module you've defined with
  `use Maxwell.Builder`. This injects methods like `get/1` and `get/2` which
  you call to execute a request of the corresponding type. In addition, the helper
  functions from `Maxwell.Conn` are also imported (e.g. `put_req_headers/2`).

  You may filter the HTTP methods exposed by your module by providing a list of
  atoms (or strings) to the `use` call, like so:

      use Maxwell.Builder, ~w(get post)a

  This will limit the methods exposed to just `get/1`, `get!/1`, `post/1`, and `post!/1`.
  If no list is provided, all possible HTTP methods are made available.

  ## Examples

       use Maxwell.Builder
       use Maxwell.Builder, ~w(get put)a
       use Maxwell.Builder, ["get", "put"]
       use Maxwell.Builder, [:get, :put]

  """
  @http_methods [:get, :head, :delete, :trace, :options, :post, :put, :patch]
  @method_without_body [{:get!, :get}, {:head!, :head}, {:delete!, :delete}, {:trace!, :trace}, {:options!, :options}]
  @method_with_body [{:post!, :post}, {:put!, :put}, {:patch!, :patch}]

  defmacro __using__(methods) do
    methods = methods |> Macro.expand(__CALLER__) |> Maxwell.Builder.Util.serialize_http_methods(@http_methods)
    Enum.each(methods, &Maxwell.Builder.Util.method_allowed?(&1, @http_methods))

    method_defs = for {method_exception, method} <- @method_without_body, method in methods do
      quote location: :keep do
        @doc """
        Executes a #{unquote(method)|> to_string |> String.upcase} request.
        It is not permitted to set a request body for this method.

        It accepts either a url as a string, or a `Maxwell.Conn.t`.

        Returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`.
        """
        @spec unquote(method)() :: {:ok, Maxwell.Conn.t} | {:error, term, Maxwell.Conn.t}
        @spec unquote(method)(String.t | Maxwell.Conn.t) :: {:ok, Maxwell.Conn.t} | {:error, term, Maxwell.Conn.t}
        def unquote(method)(conn \\ %Maxwell.Conn{})

        def unquote(method)(%Maxwell.Conn{req_body: nil} = conn) do
          call_middleware(%{conn | method: unquote(method)})
        end
        def unquote(method)(%Maxwell.Conn{} = conn) do
          raise Maxwell.Error, {__MODULE__, "#{unquote(method)}/1 should not contain body", conn};
        end
        def unquote(method)(url) when is_binary(url) do
          conn = Maxwell.Conn.new(url)
          call_middleware(%{conn | method: unquote(method)})
        end

        @doc """
        Executes a #{unquote(method_exception)|> to_string |> String.upcase} request.
        It is not permitted to set a request body for this method.

        It accepts either a url as a string, or a `Maxwell.Conn.t`.

        Returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` when status not in [200..299].
        """
        @spec unquote(method_exception)() :: Maxwell.Conn.t | no_return
        @spec unquote(method_exception)(String.t | Maxwell.Conn.t) :: Maxwell.Conn.t | no_return
        def unquote(method_exception)(conn \\ %Maxwell.Conn{}) do
          case unquote(method)(conn) do
            {:ok, %Maxwell.Conn{status: status} = conn} when status in 200..299 ->
              conn
            {:ok, conn} ->
              raise Maxwell.Error, {__MODULE__, :response_status_not_match, conn}
            {:error, reason, conn} ->
              raise Maxwell.Error, {__MODULE__, reason, conn}
          end
        end

        @doc """
        Same as #{unquote(method_exception)/1}, but takes a list of acceptable status codes.
        """
        def unquote(method_exception)(conn, normal_statuses) when is_list(normal_statuses) do
          case unquote(method)(conn) do
            {:ok, %Maxwell.Conn{status: status} = new_conn} ->
              unless status in normal_statuses do
                raise Maxwell.Error, {__MODULE__, :response_status_not_match, conn}
              end
              new_conn
            {:error, reason, new_conn}  ->
              raise Maxwell.Error, {__MODULE__, reason, new_conn}
          end
        end
      end
    end

    method_defs_with_body = for {method_exception, method} <- @method_with_body, method in methods do
      quote location: :keep do
        @doc """
        Executes a #{unquote(method)|> to_string |> String.upcase} request.

        This function accepts either a url as a string, or a `Maxwell.Conn.t` struct.

        Returns `{:ok, Maxwell.Conn.t}` or `{:error, reason, Maxwell.Conn.t}`
        """
        @spec unquote(method)() :: {:ok, Maxwell.Conn.t} | {:error, term, Maxwell.Conn.t}
        @spec unquote(method)(String.t | Maxwell.Conn.t) :: {:ok, Maxwell.Conn.t} | {:error, term, Maxwell.Conn.t}
        def unquote(method)(conn \\ %Maxwell.Conn{})

        def unquote(method)(%Maxwell.Conn{} = conn) do
          call_middleware(%{conn | method: unquote(method)})
        end
        def unquote(method)(url) when is_binary(url) do
          conn = Maxwell.Conn.new(url)
          call_middleware(%{conn | method: unquote(method)})
        end

        @doc """
        Executes a #{unquote(method_exception) |> to_string |> String.upcase} request.

        Returns `Maxwell.Conn.t` or raises `Maxwell.Error.t` when status not in [200.299]
        """
        @spec unquote(method_exception)() :: Maxwell.Conn.t | no_return
        @spec unquote(method_exception)(String.t | Maxwell.Conn.t) :: Maxwell.Conn.t | no_return
        def unquote(method_exception)(conn \\ %Maxwell.Conn{}) do
          case unquote(method)(conn) do
            {:ok, %Maxwell.Conn{status: status} = new_conn} when status in 200..299 -> new_conn;
            {:ok, new_conn} -> raise Maxwell.Error, {__MODULE__, :response_status_not_match, new_conn}
            {:error, reason, new_conn}  -> raise Maxwell.Error, {__MODULE__, reason, new_conn}
          end
        end

        @doc """
        Same as #{unquote(method_exception)}/1, but takes a list of acceptable status codes.
        """
        def unquote(method_exception)(conn, normal_statuses) when is_list(normal_statuses) do
          case unquote(method)(conn) do
            {:ok, %Maxwell.Conn{status: status} = new_conn} ->
              unless status in normal_statuses do
                raise Maxwell.Error, {__MODULE__, :response_status_not_match, new_conn}
              end
              new_conn
            {:error, reason, new_conn}  ->
              raise Maxwell.Error, {__MODULE__, reason, new_conn}
          end
        end
      end
    end

    quote do
      unquote(method_defs)
      unquote(method_defs_with_body)

      import Maxwell.Builder.Middleware
      import Maxwell.Builder.Adapter
      import Maxwell.Conn

      Module.register_attribute(__MODULE__, :middleware, accumulate: true)
      @before_compile Maxwell.Builder
    end
  end

  defp generate_call_adapter(module) do
    adapter = Module.get_attribute(module, :adapter)
    conn = quote do: conn
    adapter_call = quote_adapter_call(adapter, conn)
    quote do
      defp call_adapter(unquote(conn)) do
        unquote(adapter_call)
      end
    end
  end

  defp generate_call_middleware(module) do
    conn = quote do: conn
    call_adapter = quote do: call_adapter(unquote(conn))
    middleware = Module.get_attribute(module, :middleware)
    middleware_call = middleware |> Enum.reduce(call_adapter, &quote_middleware_call(conn, &1, &2))
    quote do
      defp call_middleware(unquote(conn)) do
        case unquote(middleware_call) do
          {:error, _} = err -> err
          {:error, _, _} = err -> err
          %Maxwell.Conn{} = ok -> {:ok, ok}
        end
      end
    end
  end

  defp quote_middleware_call(conn, {mid, args}, acc) do
    quote do
      unquote(mid).call(unquote(conn), fn
        ({:error, _} = err)    -> err
        ({:error, _, _} = err) -> err
        (unquote(conn))        -> unquote(acc)
      end, unquote(Macro.escape(args)))
    end
  end

  defp quote_adapter_call(nil, conn) do
    quote do
      unquote(Maxwell.Builder.Util.default_adapter).call(unquote(conn))
    end
  end
  defp quote_adapter_call(mod, conn) when is_atom(mod) do
    quote do
      unquote(mod).call(unquote(conn))
    end
  end

  defp quote_adapter_call(_, _) do
    raise ArgumentError, "Adapter must be a Module"
  end

  defmacro __before_compile__(conn) do
    [
      generate_call_adapter(conn.module),
      generate_call_middleware(conn.module),
    ]
  end
end
