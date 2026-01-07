# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Dsl.Command do
  @moduledoc """
  DSL entity for executing BB commands in a Reactor.

  The `command` entity wraps `BB.Reactor.Step.Command` with a cleaner syntax
  and automatic dependency handling.

  ## Example

  ```elixir
  command :move do
    command :move_to_pose
    argument :target, input(:target_pose)
    timeout 30_000
    compensate :return_home
  end
  ```
  """

  defstruct __identifier__: nil,
            arguments: [],
            async?: true,
            command: nil,
            compensate: nil,
            description: nil,
            guards: [],
            max_retries: 0,
            name: nil,
            timeout: :infinity,
            transform: nil,
            __spark_metadata__: nil

  alias BB.Reactor.Step.Command, as: CommandStep
  alias Reactor.{Builder, Dsl, Step}

  @type t :: %__MODULE__{
          arguments: [Dsl.Argument.t()],
          async?: boolean,
          command: atom,
          compensate: atom | nil,
          description: String.t() | nil,
          guards: [Dsl.Where.t() | Dsl.Guard.t()],
          max_retries: non_neg_integer(),
          name: atom,
          timeout: pos_integer() | :infinity,
          transform: nil | (any -> any),
          __identifier__: any,
          __spark_metadata__: Spark.Dsl.Entity.spark_meta()
        }

  @doc false
  def __entity__ do
    %Spark.Dsl.Entity{
      name: :command,
      describe: """
      Execute a BB command with safety handling.

      Commands are executed via `BB.Reactor.Step.Command` which monitors for
      safety state changes and supports compensation on rollback.
      """,
      examples: [
        """
        command :move do
          command :move_to_pose
          argument :target, input(:target_pose)
        end
        """,
        """
        command :grip do
          command :close_gripper
          wait_for :move
          compensate :open_gripper
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
        command: [
          type: :atom,
          required: true,
          doc: "The BB command to execute (e.g., `:move_to_pose`)."
        ],
        timeout: [
          type: {:or, [{:in, [:infinity]}, :pos_integer]},
          required: false,
          default: :infinity,
          doc: "Timeout in milliseconds for the command."
        ],
        compensate: [
          type: :atom,
          required: false,
          doc: "Command to run during undo/rollback."
        ],
        max_retries: [
          type: :non_neg_integer,
          required: false,
          default: 0,
          doc: "Maximum retry attempts on failure."
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
    def build(command, reactor) do
      impl =
        {CommandStep,
         command: command.command, timeout: command.timeout, compensate: command.compensate}

      Builder.add_step(reactor, command.name, impl, command.arguments,
        async?: command.async?,
        description: command.description,
        guards: command.guards,
        max_retries: command.max_retries,
        transform: command.transform,
        ref: :step_name
      )
    end

    def verify(_command, _dsl_state), do: :ok
  end
end
