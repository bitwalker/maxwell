defmodule Maxwell.Builder.Middleware do
  @moduledoc false

  @doc """
  Adds a middleware to the pipeline for all requests executed by a module.

  ### Examples

        middleware Maxwell.Middleware.BaseUrl, "http://httpbin.org"
        middleware Maxwell.Middleware.Json
  """
  defmacro middleware(middleware, opts \\ []) do
    quote do
      @middleware {unquote(middleware), unquote(middleware).init(unquote(opts))}
    end
  end
end
