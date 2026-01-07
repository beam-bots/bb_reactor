# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.ReactorTest do
  use ExUnit.Case, async: false

  alias BB.Message.Sensor.JointState
  alias BB.Reactor.Step.Command.Result
  alias BB.Reactor.TestRobot

  defmodule SimpleCommandReactor do
    @moduledoc false
    use Reactor, extensions: [BB.Reactor]

    input(:value)

    command :do_command do
      command(:test_succeed)
      argument(:value, input(:value))
    end

    return(:do_command)
  end

  defmodule SequentialCommandsReactor do
    @moduledoc false
    use Reactor, extensions: [BB.Reactor]

    input(:first_value)
    input(:second_value)

    command :first do
      command(:test_succeed)
      argument(:value, input(:first_value))
    end

    command :second do
      command(:test_succeed)
      argument(:value, input(:second_value))
      wait_for(:first)
    end

    return(:second)
  end

  defmodule EventFilters do
    @moduledoc false
    def has_positions?(msg), do: msg.payload.positions != []
  end

  defmodule WaitForEventReactor do
    @moduledoc false
    use Reactor, extensions: [BB.Reactor]

    wait_for_event :wait_for_joint do
      path([:sensor])
      timeout(1000)
    end

    return(:wait_for_joint)
  end

  defmodule FilteredEventReactor do
    @moduledoc false
    use Reactor, extensions: [BB.Reactor]

    wait_for_event :wait_for_position do
      path([:sensor])
      timeout(1000)
      filter(&EventFilters.has_positions?/1)
    end

    return(:wait_for_position)
  end

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})

    {:ok, cmd} = TestRobot.arm(%{})
    {:ok, :armed, _} = BB.Command.await(cmd)

    :ok
  end

  describe "command entity" do
    test "executes BB command and returns Result struct" do
      {:ok, result} =
        Reactor.run(SimpleCommandReactor, %{value: :test_value}, %{
          private: %{bb_robot: TestRobot}
        })

      assert %Result{} = result
      assert result.command == :test_succeed
      assert result.goal == %{value: :test_value}
      assert result.outcome == :test_value
    end

    test "respects wait_for dependencies" do
      {:ok, result} =
        Reactor.run(
          SequentialCommandsReactor,
          %{first_value: :first, second_value: :second},
          %{private: %{bb_robot: TestRobot}}
        )

      assert %Result{} = result
      assert result.outcome == :second
    end
  end

  describe "wait_for_event entity" do
    test "waits for PubSub event" do
      task =
        Task.async(fn ->
          Reactor.run(WaitForEventReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      Process.sleep(50)

      {:ok, message} = JointState.new(:joint1, names: [:joint1], positions: [0.5])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], message)

      {:ok, result} = Task.await(task, 2000)

      assert %BB.Message{} = result
      assert result.payload.names == [:joint1]
    end

    test "applies filter function" do
      task =
        Task.async(fn ->
          Reactor.run(FilteredEventReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      Process.sleep(50)

      {:ok, msg1} = JointState.new(:joint1, names: [:joint1], positions: [])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], msg1)

      Process.sleep(20)

      {:ok, msg2} = JointState.new(:joint1, names: [:joint1], positions: [1.0])
      BB.PubSub.publish(TestRobot, [:sensor, :joint1], msg2)

      {:ok, result} = Task.await(task, 2000)

      assert result.payload.positions == [1.0]
    end
  end

  describe "context middleware" do
    test "is automatically added by extension" do
      {:ok, result} =
        Reactor.run(SimpleCommandReactor, %{value: :test}, %{private: %{bb_robot: TestRobot}})

      assert %Result{} = result
    end
  end
end
