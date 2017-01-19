defmodule Maxwell.Builder.Adapter do
  @moduledoc false

  @doc """
  Sets the adapter for all requests from a given module.

  ### Example

       adapter Maxwell.Adapter.Hackney
  """
  defmacro adapter(adapter) do
    quote do
      @adapter unquote(adapter)
    end
  end
end
