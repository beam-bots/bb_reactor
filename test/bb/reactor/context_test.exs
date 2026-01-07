# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.ContextTest do
  use ExUnit.Case, async: true

  alias BB.Reactor.Context
  alias BB.Reactor.TestRobot

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})
    :ok
  end

  describe "new/1" do
    test "creates context with robot module" do
      context = Context.new(TestRobot)

      assert context.robot_module == TestRobot
    end

    test "populates robot struct from module" do
      context = Context.new(TestRobot)

      assert %BB.Robot{} = context.robot
      assert context.robot.name == TestRobot
    end

    test "fetches current robot state" do
      context = Context.new(TestRobot)

      assert context.robot_state == :disarmed
    end

    test "generates unique execution_id" do
      context1 = Context.new(TestRobot)
      context2 = Context.new(TestRobot)

      assert is_reference(context1.execution_id)
      assert is_reference(context2.execution_id)
      assert context1.execution_id != context2.execution_id
    end
  end

  describe "refresh_state/1" do
    test "updates robot_state from runtime" do
      context = Context.new(TestRobot)
      assert context.robot_state == :disarmed

      # Arm the robot
      {:ok, cmd} = TestRobot.arm(%{})
      {:ok, :armed, _opts} = BB.Command.await(cmd)

      # Original context still shows disarmed
      assert context.robot_state == :disarmed

      # Refresh gets current state
      refreshed = Context.refresh_state(context)
      assert refreshed.robot_state == :idle
    end
  end
end
