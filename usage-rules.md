<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# BB.Reactor Usage Rules

`bb_reactor` is a Spark DSL extension that adds robot-aware step types to
[Reactor](https://hexdocs.pm/reactor), so a saga can drive a [Beam Bots](https://hexdocs.pm/bb)
robot. It is **not** a BB component — nothing here goes in a robot's `topology`.
For BB framework basics (the DSL, the arm/disarm state machine, writing
commands) see `bb`'s rules (`mix usage_rules.sync <file> bb:all`), especially
`bb:safety-and-commands`. This file covers only how the two libraries bridge.

## Core principles

1. **It extends Reactor, not BB.** Add it to a Reactor module with
   `use Reactor, extensions: [BB.Reactor]`. That patches three entities into
   Reactor's `reactor` section — `command`, `wait_for_event`, `wait_for_state` —
   and auto-injects `BB.Reactor.Middleware.Context`.
2. **The robot is passed at run time, not compiled in.** Supply it in the
   context under `[:private, :bb_robot]`; the middleware resolves it into
   `context.private.bb` (a `%BB.Reactor.Context{}`) for every step. Omitting it
   is an `ArgumentError` before any step runs.
3. **Commands still go through the state machine.** A `command` step calls the
   generated robot function (`apply(robot, name, [goal])`), which is gated by the
   command's `allowed_states`. The reactor does **not** arm the robot for you —
   arm first (or make arming the first step), or every motion command fails from
   `:disarmed`.

## Example

A verified pick-and-place saga. Arm the robot, then run:

```elixir
defmodule MyRobot.PickAndPlace do
  use Reactor, extensions: [BB.Reactor]

  input :pick_pose
  input :place_pose

  wait_for_state :ready do
    states [:idle]
    timeout 5000
  end

  command :approach_pick do
    command :move_to_pose
    argument :target, input(:pick_pose)
    wait_for :ready
  end

  command :approach_place do
    command :move_to_pose
    argument :target, input(:place_pose)
    wait_for :approach_pick
    compensate :home
  end

  return :approach_place
end

{:ok, cmd} = MyRobot.Robot.arm(%{})
{:ok, :armed, _} = BB.Command.await(cmd)

{:ok, result} =
  Reactor.run(MyRobot.PickAndPlace, %{pick_pose: pick, place_pose: place},
    %{private: %{bb_robot: MyRobot.Robot}})
```

Each `command` step returns a `%BB.Reactor.Step.Command.Result{}` with
`:command`, `:goal`, `:outcome`, and `:robot_module`.

## Key options

- **`command`** — `command <bb_command>` (the BB command to run, required);
  `argument :key, ...` entries become the goal **map** passed to it; `timeout`
  (ms, default `:infinity`); `compensate <bb_command>` runs on rollback with
  goal `%{original: result}`; plus Reactor's own `wait_for`, `guard`,
  `max_retries`, `async?`.
- **`wait_for_event`** — `path [..]` (PubSub path, required); optional
  `message_types [Module]`, `filter &fun/1`, `timeout`. Resolves to the matching
  `%BB.Message{}`.
- **`wait_for_state`** — `states [..]` (any-of, required) and `timeout`.
- **`BB.Reactor.Middleware.Safety`** — opt-in; publishes reactor errors as
  events. It is a notification bridge only; it does not change safety state.

## Anti-patterns

- **Don't put `BB.Reactor` in the robot's `topology`.** It is a Reactor
  extension for saga modules, not a `BB.Sensor`/`BB.Actuator`/`BB.Controller`.
- **Don't forget the `bb_robot` context.** `Reactor.run/3`'s third argument must
  be `%{private: %{bb_robot: MyRobot.Robot}}` or the reactor fails to start.
- **Don't confuse the two `command`s.** The entity name (`command :approach_pick`)
  is the reactor step; the nested `command :move_to_pose` is the BB command it
  invokes.
- **Don't assume `compensate` sees the original goal.** The compensation command
  receives `%{original: result}` (the full `Result` struct), not the step's
  arguments.

## Further reading

- [bb_reactor docs](https://hexdocs.pm/bb_reactor)
- [Reactor docs](https://hexdocs.pm/reactor)
- `bb`'s command and safety rules (`bb:safety-and-commands`) and
  [Commands and State Machine](https://hexdocs.pm/bb/05-commands.html)
