# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Dsl.WaitForEvent do
  @moduledoc """
  DSL entity for waiting for PubSub events in a Reactor.

  The `wait_for_event` entity wraps `BB.Reactor.Step.WaitForEvent` with a
  cleaner syntax for subscribing to and filtering BB.PubSub messages.

  ## Example

  ```elixir
  wait_for_event :force_detected do
    path [:sensor, :force_torque]
    timeout 5000
    filter &MyFilters.force_threshold?/1
  end
  ```
  """

  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            description: nil,
            filter: nil,
            guards: [],
            message_types: [],
            name: nil,
            path: nil,
            timeout: :infinity,
            transform: nil,
            __spark_metadata__: nil

  alias BB.Reactor.Step.WaitForEvent, as: WaitForEventStep
  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          arguments: [Dsl.Argument.t()],
          async?: boolean,
          description: String.t() | nil,
          filter: (BB.Message.t() -> boolean) | nil,
          guards: [Dsl.Where.t() | Dsl.Guard.t()],
          message_types: [module],
          name: atom,
          path: [atom],
          timeout: pos_integer() | :infinity,
          transform: nil | (any -> any),
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :wait_for_event,
      describe: """
      Wait for a BB PubSub event matching a pattern.

      Subscribes to the given path and waits for a message that matches the
      optional filter function.
      """,
      examples: [
        """
        wait_for_event :joint_moved do
          path [:sensor, :joint1]
          timeout 5000
        end
        """,
        """
        wait_for_event :force_detected do
          path [:sensor, :force_torque]
          message_types [BB.Message.Sensor.ForceTorque]
          filter &MyFilters.force_threshold?/1
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
        path: [
          type: {:list, :atom},
          required: true,
          doc: "The PubSub path to subscribe to (e.g., `[:sensor, :force]`)."
        ],
        timeout: [
          type: {:or, [{:in, [:infinity]}, :pos_integer]},
          required: false,
          default: :infinity,
          doc: "Timeout in milliseconds."
        ],
        message_types: [
          type: {:list, :atom},
          required: false,
          default: [],
          doc: "List of message payload modules to filter."
        ],
        filter: [
          type: {:or, [{:fun, 1}, nil]},
          required: false,
          doc: "Optional function to filter messages: `fn message -> boolean end`."
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
    def build(wait_for_event, reactor) do
      impl =
        {WaitForEventStep,
         path: wait_for_event.path,
         timeout: wait_for_event.timeout,
         message_types: wait_for_event.message_types,
         filter: wait_for_event.filter}

      Builder.add_step(reactor, wait_for_event.name, impl, wait_for_event.arguments,
        async?: wait_for_event.async?,
        description: wait_for_event.description,
        guards: wait_for_event.guards,
        max_retries: 0,
        transform: wait_for_event.transform,
        ref: :step_name
      )
    end

    def verify(_wait_for_event, _dsl_state), do: :ok
  end
end
