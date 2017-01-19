defmodule Maxwell.Builder.Util do
  @moduledoc false

  @http_methods [:get, :head, :delete, :trace, :options, :post, :put, :patch]

  @doc """
  Gets the default HTTP adapter.

  This can be configured with:

      config :maxwell,
        default_adapter: Maxwell.Adapter.Hackney

  This is only used if an adapter is not set by the `adapter` macro in a module.

  The default adapter is `Maxwell.Adapter.Ibrowse`.
  """
  def default_adapter do
    Application.get_env(:maxwell, :default_adapter, Maxwell.Adapter.Ibrowse)
  end

  @doc """
  Serializes a list of HTTP method names to a list of lower-cased atoms.

  An error is raised if the conversion cannot be made, or if the HTTP method is invalid.
  Serialize http method to atom lists.

    * `methods` - http methods list, for example: ~w(get), [:get], ["get"]
    * `default_methods` - all http method lists.
    *  raise ArgumentError when method is not atom list, string list or ~w(get put).
  """
  def serialize_http_methods(methods, default_methods \\ [])

  def serialize_http_methods([], defaults), do: defaults
  def serialize_http_methods(methods, default_methods) do
    serialize_http_methods(methods, default_methods, [])
  end
  def serialize_http_methods([], _, acc), do: acc
  def serialize_http_methods([method|rest], default, acc) when is_atom(method) and method in @http_methods do
    serialize_http_methods(rest, default, [method|acc])
  end
  def serialize_http_methods([method|rest], default, acc) when is_binary(method) do
    atom = method |> String.downcase |> String.to_atom
    unless atom in @http_methods do
      raise ArgumentError, "Invalid HTTP method name (#{method})! Expected one of #{inspect @http_methods}"
    end
    serialize_http_methods(rest, default, [atom|acc])
  end

  @doc """
  Ensure method is in list of allowed methods.

  Raises an ArgumentError if not.

  ## Example

      iex> #{__MODULE__}.method_allowed?(:put, [:post, :head, :get])
      ** (ArgumentError) HTTP method `:put` not allowed, expected one of `[:post, :head, :get]`
  """
  def method_allowed?(method, allowed) when is_list(allowed) do
    cond do
      Enum.member?(allowed, method) ->
        true
      :else ->
        raise ArgumentError, "HTTP method `#{method}` not allowed, expected one of `#{inspect allowed}`"
    end
  end
end
