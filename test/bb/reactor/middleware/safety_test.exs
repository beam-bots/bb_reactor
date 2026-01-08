# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Middleware.SafetyTest do
  use ExUnit.Case, async: false
  use Mimic

  alias BB.Reactor.Middleware.Safety
  alias BB.Reactor.TestRobot

  setup :set_mimic_global

  setup do
    start_supervised!({TestRobot, simulation: :kinematic})

    {:ok, cmd} = TestRobot.arm(%{})
    {:ok, :armed, _} = BB.Command.await(cmd)

    :ok
  end

  describe "error/2" do
    test "reports error to BB.Safety" do
      expect(BB.Safety, :report_error, fn robot, path, err ->
        assert robot == TestRobot
        assert path == [:reactor, TestErrorReactor]
        assert %RuntimeError{message: "test error"} = err
        :ok
      end)

      context = %{
        private: %{bb_robot: TestRobot},
        __reactor__: %{id: TestErrorReactor}
      }

      error = %RuntimeError{message: "test error"}

      result = Safety.error(error, context)

      assert {:error, ^error} = result
    end
  end

  describe "middleware injection" do
    test "is not automatically added by extension" do
      defmodule TestNoSafetyReactor do
        use Reactor, extensions: [BB.Reactor]

        step :test do
          run(fn _, _ -> {:ok, :done} end)
        end

        return(:test)
      end

      reactor = TestNoSafetyReactor.reactor()

      refute BB.Reactor.Middleware.Safety in reactor.middleware
      assert BB.Reactor.Middleware.Context in reactor.middleware
    end

    test "can be manually added" do
      defmodule TestWithSafetyReactor do
        use Reactor, extensions: [BB.Reactor]

        middlewares do
          middleware(BB.Reactor.Middleware.Safety)
        end

        step :test do
          run(fn _, _ -> {:ok, :done} end)
        end

        return(:test)
      end

      reactor = TestWithSafetyReactor.reactor()

      assert BB.Reactor.Middleware.Safety in reactor.middleware
      assert BB.Reactor.Middleware.Context in reactor.middleware
    end
  end
end
