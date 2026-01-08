# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Middleware.Safety do
  @moduledoc """
  Middleware that integrates BB safety system with Reactor execution.

  When a reactor fails (returns an error), this middleware reports the error
  to `BB.Safety.report_error/3`. This allows the robot's `auto_disarm_on_error`
  configuration to control whether the robot should be automatically disarmed.

  This middleware is **not** automatically added by the `BB.Reactor` extension.
  Add it manually if you want reactor errors to trigger the safety system.

  ## Usage

  ```elixir
  defmodule MyRobot.PickAndPlace do
    use Reactor, extensions: [BB.Reactor]

    middlewares do
      middleware BB.Reactor.Middleware.Safety
    end

    # ... steps
  end
  ```

  ## Safety State Changes

  Individual steps (like `BB.Reactor.Step.Command`) are responsible for
  detecting safety state changes during execution and returning
  `{:halt, :safety_disarmed}` when appropriate. This middleware focuses
  on reporting reactor-level errors to the safety system.
  """

  use Reactor.Middleware

  @impl true
  def error(error, context) do
    robot = context.private.bb_robot
    reactor_id = context.__reactor__.id
    BB.Safety.report_error(robot, [:reactor, reactor_id], error)
    {:error, error}
  end
end
