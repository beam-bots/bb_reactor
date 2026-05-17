# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Middleware.Safety do
  @moduledoc """
  Middleware that bridges reactor errors to the BB safety event stream.

  When a reactor fails (returns an error), this middleware publishes the
  error via `BB.Safety.report_error/3`. The result is a
  `BB.Safety.HardwareError` message on `[:safety, :error]` that observers
  (dashboards, alerting, custom recovery logic) can subscribe to.

  This middleware does **not** disarm the robot or otherwise change safety
  state. Escalation in BB happens through the supervision tree: if a process
  crashes often enough to exhaust the topology supervisor's restart budget,
  the safety controller force-disarms the robot. Reactor errors are
  recovered at the saga level (compensation, retries) and do not crash
  processes, so they will not trigger escalation on their own. If a
  particular reactor failure warrants disarm, subscribe to `[:safety, :error]`
  and call `BB.Safety.disarm/1` explicitly.

  This middleware is **not** automatically added by the `BB.Reactor`
  extension - add it manually if you want reactor errors published as
  hardware error events.

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

  ## Safety State Changes Within Steps

  Individual steps (like `BB.Reactor.Step.Command`) are responsible for
  detecting safety state changes during execution and returning
  `{:halt, :safety_disarmed}` when appropriate. This middleware only
  publishes notifications for reactor-level errors.
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
