# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.Command do
  @moduledoc """
  Reactor step that executes a BB command.

  This step wraps BB.Command execution with process monitoring to detect
  safety disarm events. When a command stops due to safety state change,
  the step returns `{:halt, :safety_disarmed}` to stop the reactor.

  ## Options

  - `:command` - (required) The command name as an atom (e.g., `:move_to`)
  - `:timeout` - Timeout in milliseconds (default: `:infinity`)
  - `:compensate` - Command to run during undo (e.g., `:return_home`)

  ## Result

  Returns a `BB.Reactor.Step.Command.Result` struct containing:

  - `:command` - The command name that was executed
  - `:goal` - The goal map passed to the command
  - `:outcome` - The result returned by the command
  - `:robot_module` - The robot module used

  ## Compensation (Undo)

  If `:compensate` is specified and the reactor needs to roll back this step,
  the compensation command is invoked with `%{original: result}` as its goal,
  giving it access to the original command, goal, and outcome.

  ## Safety Handling

  The step monitors the command process. If the command exits with `:disarmed`
  reason (due to safety state change), the step returns `{:halt, :safety_disarmed}`
  which stops the reactor execution.
  """

  use Reactor.Step

  alias BB.Command.ResultCache

  defmodule Result do
    @moduledoc """
    Structured result from command execution.

    Contains all information needed for dependent steps and compensation.
    """
    defstruct [:command, :goal, :outcome, :robot_module]

    @type t :: %__MODULE__{
            command: atom(),
            goal: map(),
            outcome: term(),
            robot_module: module()
          }
  end

  @impl true
  def run(arguments, context, options) do
    bb = context.private.bb
    robot = bb.robot_module
    command_name = Keyword.fetch!(options, :command)
    goal = build_goal(arguments)

    result_base = %Result{
      command: command_name,
      goal: goal,
      robot_module: robot
    }

    case apply(robot, command_name, [goal]) do
      {:ok, cmd_pid} ->
        ref = Process.monitor(cmd_pid)
        await_with_monitor(cmd_pid, ref, result_base, options)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def undo(result, _arguments, context, options) do
    case Keyword.get(options, :compensate) do
      nil ->
        :ok

      compensation_cmd ->
        run_compensation(compensation_cmd, result, context)
    end
  end

  defp await_with_monitor(cmd_pid, ref, result_base, options) do
    timeout = Keyword.get(options, :timeout, :infinity)
    do_await(cmd_pid, ref, result_base, timeout)
  end

  defp do_await(cmd_pid, ref, result_base, :infinity) do
    receive do
      {:DOWN, ^ref, :process, ^cmd_pid, :disarmed} ->
        {:halt, :safety_disarmed}

      {:DOWN, ^ref, :process, ^cmd_pid, :cancelled} ->
        {:error, :cancelled}

      {:DOWN, ^ref, :process, ^cmd_pid, :normal} ->
        handle_normal_exit(cmd_pid, result_base)

      {:DOWN, ^ref, :process, ^cmd_pid, :noproc} ->
        # Process was already dead when we monitored - it likely completed
        # successfully before we could monitor. Check the result cache.
        handle_normal_exit(cmd_pid, result_base)

      {:DOWN, ^ref, :process, ^cmd_pid, reason} ->
        {:error, {:command_crashed, reason}}
    end
  end

  defp do_await(cmd_pid, ref, result_base, timeout) when is_integer(timeout) do
    receive do
      {:DOWN, ^ref, :process, ^cmd_pid, :disarmed} ->
        {:halt, :safety_disarmed}

      {:DOWN, ^ref, :process, ^cmd_pid, :cancelled} ->
        {:error, :cancelled}

      {:DOWN, ^ref, :process, ^cmd_pid, :normal} ->
        handle_normal_exit(cmd_pid, result_base)

      {:DOWN, ^ref, :process, ^cmd_pid, :noproc} ->
        # Process was already dead when we monitored - check the result cache
        handle_normal_exit(cmd_pid, result_base)

      {:DOWN, ^ref, :process, ^cmd_pid, reason} ->
        {:error, {:command_crashed, reason}}
    after
      timeout ->
        Process.demonitor(ref, [:flush])
        BB.Command.cancel(cmd_pid)
        {:error, :timeout}
    end
  end

  defp handle_normal_exit(cmd_pid, result_base) do
    case ResultCache.fetch_and_delete(cmd_pid) do
      {:ok, {:ok, outcome}} ->
        {:ok, %{result_base | outcome: outcome}}

      {:ok, {:ok, outcome, _opts}} ->
        {:ok, %{result_base | outcome: outcome}}

      {:ok, {:error, reason}} ->
        {:error, reason}

      :error ->
        {:error, :result_not_found}
    end
  end

  defp run_compensation(cmd, %Result{} = result, context) do
    bb = context.private.bb
    robot = bb.robot_module
    goal = %{original: result}

    case apply(robot, cmd, [goal]) do
      {:ok, cmd_pid} ->
        ref = Process.monitor(cmd_pid)
        await_compensation(cmd_pid, ref)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp await_compensation(cmd_pid, ref) do
    receive do
      {:DOWN, ^ref, :process, ^cmd_pid, :normal} ->
        :ok

      {:DOWN, ^ref, :process, ^cmd_pid, reason} ->
        {:error, {:compensation_failed, reason}}
    after
      30_000 ->
        Process.demonitor(ref, [:flush])
        BB.Command.cancel(cmd_pid)
        {:error, :compensation_timeout}
    end
  end

  defp build_goal(arguments) do
    Map.new(arguments)
  end
end
