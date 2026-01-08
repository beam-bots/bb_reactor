# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.WaitForStateTest do
  use ExUnit.Case, async: false

  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias BB.Reactor.Step.WaitForState
  alias BB.Reactor.TestRobot

  defmodule WaitForIdleReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_for_idle do
      impl({WaitForState, states: [:idle], timeout: 2000})
    end

    return(:wait_for_idle)
  end

  defmodule WaitForMultipleStatesReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_for_ready do
      impl({WaitForState, states: [:idle, :executing], timeout: 2000})
    end

    return(:wait_for_ready)
  end

  defmodule TimeoutReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :wait_timeout do
      impl({WaitForState, states: [:nonexistent_state], timeout: 50})
    end

    return(:wait_timeout)
  end

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})
    :ok
  end

  describe "run/3" do
    test "returns immediately if already in target state" do
      {:ok, cmd} = TestRobot.arm(%{})
      {:ok, :armed, _} = BB.Command.await(cmd)

      {:ok, result} =
        Reactor.run(WaitForIdleReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert result == :idle
    end

    test "waits for state transition" do
      task =
        Task.async(fn ->
          Reactor.run(WaitForIdleReactor, %{}, %{private: %{bb_robot: TestRobot}})
        end)

      Process.sleep(50)

      {:ok, cmd} = TestRobot.arm(%{})
      {:ok, :armed, _} = BB.Command.await(cmd)

      {:ok, result} = Task.await(task, 3000)

      assert result == :idle
    end

    test "matches any of multiple target states" do
      {:ok, cmd} = TestRobot.arm(%{})
      {:ok, :armed, _} = BB.Command.await(cmd)

      {:ok, result} =
        Reactor.run(WaitForMultipleStatesReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert result in [:idle, :executing]
    end

    test "returns timeout error when target state not reached" do
      {:error, error} =
        Reactor.run(TimeoutReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert unwrap_error(error) == :timeout
    end
  end

  defp unwrap_error(%Reactor.Error.Invalid{errors: [%{error: error} | _]}), do: error
  defp unwrap_error(error), do: error
end
