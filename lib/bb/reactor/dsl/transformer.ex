# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Dsl.Transformer do
  @moduledoc false

  use Spark.Dsl.Transformer

  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias Spark.Dsl.Transformer

  @required_middlewares [ContextMiddleware]

  @impl true
  def before?(Reactor.Dsl.Transformer), do: true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    existing_middlewares =
      dsl_state
      |> Transformer.get_entities([:reactor, :middlewares])
      |> Enum.map(fn
        %Reactor.Dsl.Middleware{module: module} -> module
        other -> other
      end)

    dsl_state =
      Enum.reduce(@required_middlewares, dsl_state, fn middleware, acc ->
        if middleware in existing_middlewares do
          acc
        else
          entity = %Reactor.Dsl.Middleware{
            __identifier__: middleware,
            module: middleware
          }

          Transformer.add_entity(acc, [:reactor, :middlewares], entity)
        end
      end)

    {:ok, dsl_state}
  end
end
