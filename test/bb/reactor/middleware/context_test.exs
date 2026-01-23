# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Middleware.ContextTest do
  use ExUnit.Case, async: false

  alias BB.Reactor.Context
  alias BB.Reactor.Middleware.Context, as: ContextMiddleware
  alias BB.Reactor.TestRobot

  defmodule ContextCapturingStep do
    @moduledoc false
    use Reactor.Step

    @impl true
    def run(_arguments, context, _options) do
      {:ok, context.private.bb}
    end
  end

  defmodule TestReactor do
    @moduledoc false
    use Reactor

    middlewares do
      middleware(ContextMiddleware)
    end

    step :capture_context do
      impl(ContextCapturingStep)
    end

    return(:capture_context)
  end

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})
    :ok
  end

  describe "init/1" do
    test "injects BB context into reactor context" do
      {:ok, result} = Reactor.run(TestReactor, %{}, %{private: %{bb_robot: TestRobot}})

      assert %Context{} = result
      assert result.robot_module == TestRobot
      assert %BB.Robot{} = result.robot
      assert result.robot_state == :disarmed
      assert is_reference(result.execution_id)
    end

    test "returns error when bb_robot is not provided" do
      {:error, errors} = Reactor.run(TestReactor, %{}, %{})

      assert Exception.message(errors) =~
               "BB.Reactor.Middleware.Context requires :bb_robot in context.private"
    end
  end
end
