# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Dsl.Transformer do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias Spark.Dsl.Transformer

  @impl true
  def before?(Reactor.Dsl.Transformer), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    middlewares =
      dsl_state
      |> Transformer.get_entities([:reactor, :middlewares])
      |> Enum.map(fn
        %Reactor.Dsl.Middleware{module: module} -> module
        other -> other
      end)

    if ContextMiddleware in middlewares do
      {:ok, dsl_state}
    else
      middleware_entity = %Reactor.Dsl.Middleware{
        __identifier__: ContextMiddleware,
        module: ContextMiddleware
      }

      {:ok, Transformer.add_entity(dsl_state, [:reactor, :middlewares], middleware_entity)}
    end
  end
end
