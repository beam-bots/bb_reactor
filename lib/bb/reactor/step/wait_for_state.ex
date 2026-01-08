# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.WaitForState do
  @moduledoc """
  Reactor step that waits for a robot to reach a specific state.

  This step checks the current robot state and, if not already in a target
  state, subscribes to `[:state_machine]` events and waits for a transition
  to one of the target states.

  ## Options

  - `:states` - (required) List of target states to wait for
  - `:timeout` - Timeout in milliseconds (default: `:infinity`)

  ## Result

  Returns the state that was reached on success.

  ## Examples

  ```elixir
  step :wait_for_idle do
    impl {BB.Reactor.Step.WaitForState, states: [:idle], timeout: 5000}
  end

  step :wait_for_ready do
    impl {BB.Reactor.Step.WaitForState, states: [:idle, :executing]}
  end
  ```
  """

  use Reactor.Step

  alias BB.Robot.Runtime
  alias BB.StateMachine.Transition

  @impl true
  def run(_arguments, context, options) do
    bb = context.private.bb
    robot = bb.robot_module
    target_states = Keyword.fetch!(options, :states)
    timeout = Keyword.get(options, :timeout, :infinity)

    current_state = Runtime.state(robot)

    if current_state in target_states do
      {:ok, current_state}
    else
      case BB.PubSub.subscribe(robot, [:state_machine]) do
        {:ok, _pid} ->
          result = await_state(target_states, timeout)
          BB.PubSub.unsubscribe(robot, [:state_machine])
          result

        {:error, reason} ->
          {:error, {:subscription_failed, reason}}
      end
    end
  end

  defp await_state(target_states, :infinity) do
    receive do
      {:bb, [:state_machine], %{payload: %Transition{to: to}}} ->
        if to in target_states do
          {:ok, to}
        else
          await_state(target_states, :infinity)
        end
    end
  end

  defp await_state(target_states, timeout) when is_integer(timeout) do
    start_time = System.monotonic_time(:millisecond)
    do_await_state(target_states, timeout, start_time)
  end

  defp do_await_state(target_states, timeout, start_time) do
    remaining = timeout - (System.monotonic_time(:millisecond) - start_time)

    if remaining <= 0 do
      {:error, :timeout}
    else
      receive do
        {:bb, [:state_machine], %{payload: %Transition{to: to}}} ->
          if to in target_states do
            {:ok, to}
          else
            do_await_state(target_states, timeout, start_time)
          end
      after
        remaining ->
          {:error, :timeout}
      end
    end
  end
end
