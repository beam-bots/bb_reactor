# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor.Step.WaitForEvent do
  @moduledoc """
  Reactor step that waits for a BB PubSub event.

  This step subscribes to BB.PubSub and waits for a message matching the
  specified path and optional filter function.

  ## Options

  - `:path` - (required) The PubSub path to subscribe to (e.g., `[:sensor, :force]`)
  - `:timeout` - Timeout in milliseconds (default: `:infinity`)
  - `:message_types` - List of message payload modules to filter (default: `[]` for all)
  - `:filter` - Optional function to filter messages: `fn message -> boolean end`

  ## Result

  Returns the matching `BB.Message` struct on success.

  ## Examples

  ```elixir
  step :wait_for_force do
    impl {BB.Reactor.Step.WaitForEvent,
      path: [:sensor, :force_torque],
      timeout: 5000,
      filter: fn msg -> msg.payload.force > 10.0 end}
  end
  ```
  """

  use Reactor.Step

  @impl true
  def run(_arguments, context, options) do
    bb = context.private.bb
    robot = bb.robot_module
    path = Keyword.fetch!(options, :path)
    timeout = Keyword.get(options, :timeout, :infinity)
    message_types = Keyword.get(options, :message_types, [])
    filter = Keyword.get(options, :filter)

    case BB.PubSub.subscribe(robot, path, message_types: message_types) do
      {:ok, _pid} ->
        result = await_event(path, timeout, filter)
        BB.PubSub.unsubscribe(robot, path)
        result

      {:error, reason} ->
        {:error, {:subscription_failed, reason}}
    end
  end

  defp await_event(path, :infinity, filter) do
    receive do
      {:bb, source_path, message} when is_list(source_path) ->
        if matches_filter?(message, filter) do
          {:ok, message}
        else
          await_event(path, :infinity, filter)
        end
    end
  end

  defp await_event(path, timeout, filter) when is_integer(timeout) do
    start_time = System.monotonic_time(:millisecond)
    do_await_event(path, timeout, filter, start_time)
  end

  defp do_await_event(path, timeout, filter, start_time) do
    remaining = timeout - (System.monotonic_time(:millisecond) - start_time)

    if remaining <= 0 do
      {:error, :timeout}
    else
      receive do
        {:bb, source_path, message} when is_list(source_path) ->
          if matches_filter?(message, filter) do
            {:ok, message}
          else
            do_await_event(path, timeout, filter, start_time)
          end
      after
        remaining ->
          {:error, :timeout}
      end
    end
  end

  defp matches_filter?(_message, nil), do: true
  defp matches_filter?(message, filter) when is_function(filter, 1), do: filter.(message)
end
