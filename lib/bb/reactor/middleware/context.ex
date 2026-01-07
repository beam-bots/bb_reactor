# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Middleware.Context do
  @moduledoc """
  Middleware that injects BB context into the reactor.

  This middleware must be included in any reactor that uses BB steps. It creates
  a `BB.Reactor.Context` and stores it in `context.private.bb`, making robot
  information available to all steps.

  ## Usage

  Add to your reactor's middleware:

  ```elixir
  defmodule MyRobot.PickAndPlace do
    use Reactor, extensions: [BB.Reactor]

    # BB.Reactor extension automatically adds this middleware
    # ...
  end
  ```

  Or manually:

  ```elixir
  defmodule MyReactor do
    use Reactor

    middlewares do
      middleware {BB.Reactor.Middleware.Context, robot: MyRobot}
    end
  end
  ```

  ## Accessing Context in Steps

  ```elixir
  def run(arguments, context, options) do
    bb = context.private.bb

    # Access robot module
    robot = bb.robot_module

    # Access static robot struct
    links = bb.robot.links

    # Check current state
    if bb.robot_state == :idle do
      # ...
    end
  end
  ```
  """

  use Reactor.Middleware

  alias BB.Reactor.Context

  @impl Reactor.Middleware
  def init(context) do
    case context.private[:bb_robot] do
      nil ->
        {:error,
         ArgumentError.exception(
           message: "BB.Reactor.Middleware.Context requires :bb_robot in context.private"
         )}

      robot_module ->
        bb_context = Context.new(robot_module)
        {:ok, put_in(context, [:private, :bb], bb_context)}
    end
  end
end
