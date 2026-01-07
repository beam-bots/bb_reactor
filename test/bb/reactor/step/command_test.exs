# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.CommandTest do
  use ExUnit.Case, async: false

  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias BB.Reactor.Step.Command
  alias BB.Reactor.Step.Command.Result
  alias BB.Reactor.TestRobot

  # Helper to extract the actual error from Reactor's error wrapper
  defp unwrap_error(%Reactor.Error.Invalid{errors: [%{error: error} | _]}), do: error
  defp unwrap_error(error), do: error

  defmodule SuccessReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    input(:value)

    step :do_command do
      impl({Command, command: :test_succeed})
      argument(:value, input(:value))
    end

    return(:do_command)
  end

  defmodule FailReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    input(:reason)

    step :do_command do
      impl({Command, command: :test_fail})
      argument(:reason, input(:reason))
    end

    return(:do_command)
  end

  defmodule TimeoutReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :do_command do
      impl({Command, command: :test_slow, timeout: 50})
      argument(:delay, value(1000))
    end

    return(:do_command)
  end

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})

    # Arm the robot so commands can run
    {:ok, cmd} = TestRobot.arm(%{})
    {:ok, :armed, _} = BB.Command.await(cmd)

    :ok
  end

  describe "run/3" do
    test "executes command and returns Result struct" do
      {:ok, result} =
        Reactor.run(SuccessReactor, %{value: :test_value}, %{private: %{bb_robot: TestRobot}})

      assert %Result{} = result
      assert result.command == :test_succeed
      assert result.goal == %{value: :test_value}
      assert result.outcome == :test_value
      assert result.robot_module == TestRobot
    end

    test "returns error when command fails" do
      {:error, error} =
        Reactor.run(FailReactor, %{reason: :custom_error}, %{private: %{bb_robot: TestRobot}})

      assert unwrap_error(error) == :custom_error
    end

    test "returns error on timeout" do
      {:error, error} =
        Reactor.run(TimeoutReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert unwrap_error(error) == :timeout
    end
  end

  describe "safety disarm handling" do
    defmodule DisarmDuringCommandReactor do
      @moduledoc false
      use Reactor

      middlewares do
        middleware(ContextMiddleware)
      end

      step :slow_command do
        impl({Command, command: :test_slow})
        argument(:delay, value(500))
      end

      return(:slow_command)
    end

    test "stops reactor when command is disarmed" do
      # Start the reactor in a task so we can disarm while it runs
      task =
        Task.async(fn ->
          Reactor.run(DisarmDuringCommandReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      # Give the command time to start
      Process.sleep(50)

      # Disarm the robot - this cancels the running command
      {:ok, disarm_cmd} = TestRobot.disarm(%{})
      {:ok, :disarmed, _} = BB.Command.await(disarm_cmd)

      # The reactor should stop (either halt or error)
      result = Task.await(task, 5000)

      # When a command is cancelled due to disarm, it exits with :cancelled
      # Our step returns {:error, :cancelled} for this case
      case result do
        {:halted, reactor} ->
          # If BB properly sends :disarmed exit reason
          assert reactor.state == :halted

        {:error, error} ->
          # If BB cancels the command directly (current behavior)
          assert unwrap_error(error) == :cancelled
      end
    end
  end
end
