# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Dsl.WaitForState do
  @moduledoc """
  DSL entity for waiting for robot states in a Reactor.

  The `wait_for_state` entity wraps `BB.Reactor.Step.WaitForState` with a
  cleaner syntax for waiting until the robot reaches a specific state.

  ## Example

  ```elixir
  wait_for_state :wait_for_idle do
    states [:idle]
    timeout 5000
  end
  ```
  """

  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            description: nil,
            guards: [],
            name: nil,
            states: [],
            timeout: :infinity,
            transform: nil,
            __spark_metadata__: nil

  alias BB.Reactor.Step.WaitForState, as: WaitForStateStep
  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          arguments: [Dsl.Argument.t()],
          async?: boolean,
          description: String.t() | nil,
          guards: [Dsl.Where.t() | Dsl.Guard.t()],
          name: atom,
          states: [atom],
          timeout: pos_integer() | :infinity,
          transform: nil | (any -> any),
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :wait_for_state,
      describe: """
      Wait for the robot to reach one of the specified states.

      Checks the current robot state and, if not already in a target state,
      subscribes to state machine transitions and returns when the robot
      enters one of the target states.
      """,
      examples: [
        """
        wait_for_state :wait_for_idle do
          states [:idle]
          timeout 5000
        end
        """,
        """
        wait_for_state :wait_for_ready do
          states [:idle, :executing]
        end
        """
      ],
      args: [:name],
      target: __MODULE__,
      identifier: :name,
      entities: [
        arguments: [Dsl.Argument.__entity__(), Dsl.WaitFor.__entity__()],
        guards: [Dsl.Where.__entity__(), Dsl.Guard.__entity__()]
      ],
      schema: [
        name: [
          type: :atom,
          required: true,
          doc: "A unique name for the step."
        ],
        states: [
          type: {:list, :atom},
          required: true,
          doc: "List of target states to wait for (e.g., `[:idle]`, `[:armed, :idle]`)."
        ],
        timeout: [
          type: {:or, [{:in, [:infinity]}, :pos_integer]},
          required: false,
          default: :infinity,
          doc: "Timeout in milliseconds."
        ],
        async?: [
          type: :boolean,
          required: false,
          default: true,
          doc: "Whether to run the step asynchronously."
        ],
        description: [
          type: :string,
          required: false,
          doc: "An optional description for the step."
        ],
        transform: [
          type: {:or, [{:spark_function_behaviour, Step, {Step.TransformAll, 1}}, nil]},
          required: false,
          default: nil,
          doc: "Optional transformation for the result."
        ]
      ]
    }
  end

  defimpl Reactor.Dsl.Build do
    def build(wait_for_state, reactor) do
      impl =
        {WaitForStateStep, states: wait_for_state.states, timeout: wait_for_state.timeout}

      Builder.add_step(reactor, wait_for_state.name, impl, wait_for_state.arguments,
        async?: wait_for_state.async?,
        description: wait_for_state.description,
        guards: wait_for_state.guards,
        max_retries: 0,
        transform: wait_for_state.transform,
        ref: :step_name
      )
    end

    def verify(_wait_for_state, _dsl_state), do: :ok
  end
end
