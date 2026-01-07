# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.WaitForEventTest do
  use ExUnit.Case, async: false

  alias BB.Message.Sensor.JointState
  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias BB.Reactor.Step.WaitForEvent
  alias BB.Reactor.TestRobot

  defmodule Filters do
    @moduledoc false
    def has_positions?(msg), do: msg.payload.positions != []
  end

  defmodule BasicWaitReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_for_joint do
      impl({WaitForEvent, path: [:sensor], timeout: 1000})
    end

    return(:wait_for_joint)
  end

  defmodule FilteredWaitReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_for_specific do
      impl({WaitForEvent, path: [:sensor], timeout: 1000, filter: &Filters.has_positions?/1})
    end

    return(:wait_for_specific)
  end

  defmodule MessageTypesReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_for_joint_state do
      impl({WaitForEvent, path: [:sensor], timeout: 1000, message_types: [JointState]})
    end

    return(:wait_for_joint_state)
  end

  defmodule TimeoutReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_timeout do
      impl({WaitForEvent, path: [:sensor], timeout: 50})
    end

    return(:wait_timeout)
  end

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})
    :ok
  end

  describe "run/3" do
    test "receives published message" do
      # Start reactor in a task
      task =
        Task.async(fn ->
          Reactor.run(BasicWaitReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      # Give the reactor time to subscribe
      Process.sleep(50)

      # Publish a message
      {:ok, message} = JointState.new(:joint1, names: [:joint1], positions: [0.5])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], message)

      # Reactor should receive it
      {:ok, result} = Task.await(task, 2000)

      assert %BB.Message{} = result
      assert result.payload.names == [:joint1]
      assert result.payload.positions == [0.5]
    end

    test "filters messages with filter function" do
      task =
        Task.async(fn ->
          Reactor.run(FilteredWaitReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      Process.sleep(50)

      # Publish a message that doesn't match filter (empty positions)
      {:ok, msg1} = JointState.new(:joint1, names: [:joint1], positions: [])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], msg1)

      # Should not match - reactor still waiting
      Process.sleep(20)

      # Publish a message that matches filter
      {:ok, msg2} = JointState.new(:joint1, names: [:joint1], positions: [1.0])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], msg2)

      {:ok, result} = Task.await(task, 2000)

      # Should receive the second message
      assert result.payload.positions == [1.0]
    end

    test "returns timeout error when no message received" do
      {:error, error} =
        Reactor.run(TimeoutReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert unwrap_error(error) == :timeout
    end

    test "respects message_types filter" do
      task =
        Task.async(fn ->
          Reactor.run(MessageTypesReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      Process.sleep(50)

      # Publish a JointState message
      {:ok, message} = JointState.new(:joint1, names: [:joint1], positions: [0.0])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], message)

      {:ok, result} = Task.await(task, 2000)

      assert %JointState{} = result.payload
    end
  end

  defp unwrap_error(%Reactor.Error.Invalid{errors: [%{error: error} | _]}), do: error
  defp unwrap_error(error), do: error
end
