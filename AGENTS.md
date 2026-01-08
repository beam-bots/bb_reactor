<!--
SPDX-FileCopyrightText: 2026 James Harton

SPDX-License-Identifier: Apache-2.0
-->

# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Project Overview

BB.Reactor is a Spark DSL extension that integrates [Reactor](https://hexdocs.pm/reactor) with the [BB robotics framework](https://github.com/beam-bots/bb). It provides DSL entities for building robot operation sequences with proper safety handling and compensation.

## Architecture

### Extension (`lib/bb/reactor.ex`)

The main Spark DSL extension that adds three entities to Reactor:
- `command` - Execute BB commands
- `wait_for_event` - Wait for PubSub events
- `wait_for_state` - Wait for robot state transitions

### Steps (`lib/bb/reactor/step/`)

Reactor step implementations:
- `Command` - Executes BB commands, monitors for safety disarm, supports compensation
- `WaitForEvent` - Subscribes to BB.PubSub and waits for matching messages
- `WaitForState` - Subscribes to state machine transitions

### DSL Entities (`lib/bb/reactor/dsl/`)

Spark DSL entity definitions that build into steps:
- `Command` - Schema and builder for command entity
- `WaitForEvent` - Schema and builder for wait_for_event entity
- `WaitForState` - Schema and builder for wait_for_state entity
- `Transformer` - Auto-injects Context middleware

### Middleware (`lib/bb/reactor/middleware/`)

- `Context` - Auto-injected; creates `BB.Reactor.Context` and stores in `context.private.bb`
- `Safety` - Opt-in; reports reactor errors to `BB.Safety.report_error/3`

### Context (`lib/bb/reactor/context.ex`)

Struct holding robot module reference, available to steps via `context.private.bb`.

## Common Commands

```bash
# Run all checks
BB_VERSION=local mix check --no-retry

# Run tests
BB_VERSION=local mix test

# Generate docs
BB_VERSION=local mix docs
```

Note: `BB_VERSION=local` uses the local BB dependency from `../bb`.

## Key Patterns

### Accessing Robot in Steps

```elixir
def run(_arguments, context, options) do
  bb = context.private.bb
  robot = bb.robot_module
  # Use robot module...
end
```

### DSL Entity Structure

Each DSL entity has:
1. Struct with fields matching DSL options
2. `__entity__/0` returning `%Spark.Dsl.Entity{}`
3. `Reactor.Dsl.Build` protocol implementation

### Safety Handling

- Command step detects `:disarmed` exit reason and returns `{:halt, :safety_disarmed}`
- Safety middleware (opt-in) reports errors to `BB.Safety.report_error/3`

## Dependencies

- `bb` - BB robotics framework
- `reactor` - Saga orchestrator
- `spark` - DSL framework

## Testing

Tests use `BB.Reactor.TestRobot` from `test/support/test_robot.ex` which provides:
- Simulation mode (`:kinematic`)
- Test commands (`:test_succeed`, `:test_fail`, `:test_slow`)
