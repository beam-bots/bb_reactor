# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Context do
  @moduledoc """
  BB context for reactor execution.

  This struct is injected into the reactor context by `BB.Reactor.Middleware.Context`
  and made available to all steps as `context.private.bb`.

  ## Fields

  - `:robot_module` - The robot module (e.g., `MyRobot`)
  - `:robot` - The static `BB.Robot` struct from `robot_module.robot()`
  - `:robot_state` - The current robot state (`:disarmed`, `:idle`, `:executing`, etc.)
  - `:execution_id` - Unique identifier for this reactor execution

  ## Usage in Steps

  ```elixir
  def run(arguments, context, options) do
    bb = context.private.bb
    robot = bb.robot_module

    # Use robot module to invoke commands
    apply(robot, :move_to, [goal])
  end
  ```
  """

  alias BB.Robot.Runtime

  defstruct [
    :robot_module,
    :robot,
    :robot_state,
    :execution_id
  ]

  @type t :: %__MODULE__{
          robot_module: module(),
          robot: BB.Robot.t(),
          robot_state: Runtime.robot_state(),
          execution_id: reference()
        }

  @doc """
  Create a new BB context for a reactor execution.

  ## Arguments

  - `robot_module` - The robot module to use for this execution

  ## Examples

      iex> BB.Reactor.Context.new(MyRobot)
      %BB.Reactor.Context{
        robot_module: MyRobot,
        robot: %BB.Robot{...},
        robot_state: :idle,
        execution_id: #Reference<...>
      }
  """
  @spec new(module()) :: t()
  def new(robot_module) when is_atom(robot_module) do
    %__MODULE__{
      robot_module: robot_module,
      robot: robot_module.robot(),
      robot_state: Runtime.state(robot_module),
      execution_id: make_ref()
    }
  end

  @doc """
  Refresh the robot state from the runtime.

  Call this to get the current robot state if it may have changed.
  """
  @spec refresh_state(t()) :: t()
  def refresh_state(%__MODULE__{robot_module: robot_module} = context) do
    %{context | robot_state: Runtime.state(robot_module)}
  end
end
