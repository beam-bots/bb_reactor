<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

<img src="https://github.com/beam-bots/bb/blob/main/logos/beam_bots_logo.png?raw=true" alt="Beam Bots Logo" width="250" />

# BB.Reactor

[![CI](https://github.com/beam-bots/bb_reactor/actions/workflows/ci.yml/badge.svg)](https://github.com/beam-bots/bb_reactor/actions/workflows/ci.yml)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache--2.0-green.svg)](https://opensource.org/licenses/Apache-2.0)
[![Hex version badge](https://img.shields.io/hexpm/v/bb_reactor.svg)](https://hex.pm/packages/bb_reactor)
[![REUSE status](https://api.reuse.software/badge/github.com/beam-bots/bb_reactor)](https://api.reuse.software/info/github.com/beam-bots/bb_reactor)

Spark DSL extension for integrating [Reactor](https://hexdocs.pm/reactor) with the [BB robotics framework](https://github.com/beam-bots/bb).

## Installation

Add `bb_reactor` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bb_reactor, "~> 0.1"}
  ]
end
```

## Usage

```elixir
defmodule MyRobot.PickAndPlace do
  use Reactor, extensions: [BB.Reactor]

  input :pick_pose
  input :place_pose

  # Wait for robot to be ready
  wait_for_state :ready do
    states [:idle]
    timeout 5000
  end

  # Execute movement command
  command :approach do
    command :move_to_pose
    argument :target, input(:pick_pose)
    wait_for :ready
  end

  # Close gripper
  command :grip do
    command :close_gripper
    wait_for :approach
  end

  # Wait for force sensor event
  wait_for_event :gripped do
    path [:sensor, :force]
    timeout 2000
    wait_for :grip
  end

  # Move to place position with compensation
  command :retreat do
    command :move_to_pose
    argument :target, input(:place_pose)
    wait_for :gripped
    compensate :return_home
  end

  return :retreat
end

# Run the reactor
Reactor.run(MyRobot.PickAndPlace, inputs, %{private: %{bb_robot: MyRobot}})
```

## Entities

### `command`

Execute a BB command with safety handling and compensation support.

```elixir
command :move do
  command :move_to_pose           # The BB command to execute
  argument :target, input(:pose)  # Arguments passed to the command
  timeout 30_000                  # Optional timeout (default: :infinity)
  compensate :return_home         # Optional compensation command for undo
end
```

### `wait_for_event`

Wait for a PubSub event matching a pattern.

```elixir
wait_for_event :force_detected do
  path [:sensor, :force_torque]   # PubSub path to subscribe to
  timeout 5000                    # Optional timeout
  message_types [ForceTorque]     # Optional: filter by message type
  filter &MyFilters.threshold?/1  # Optional: custom filter function
end
```

### `wait_for_state`

Wait for the robot to reach a specific state.

```elixir
wait_for_state :wait_for_idle do
  states [:idle]                  # Target states (any-of matching)
  timeout 5000                    # Optional timeout
end
```

## Safety Integration

The `BB.Reactor.Middleware.Safety` middleware can be added to report reactor errors to the BB safety system:

```elixir
defmodule MyRobot.SafeReactor do
  use Reactor, extensions: [BB.Reactor]

  middlewares do
    middleware BB.Reactor.Middleware.Safety
  end

  # ... steps
end
```

This allows the robot's `auto_disarm_on_error` configuration to control whether errors trigger automatic disarm.

## Documentation

- [HexDocs](https://hexdocs.pm/bb_reactor)
- [BB Framework](https://hexdocs.pm/bb)
- [Reactor](https://hexdocs.pm/reactor)

## License

Apache License 2.0
