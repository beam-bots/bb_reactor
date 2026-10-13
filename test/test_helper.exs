# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

Application.ensure_all_started(:mimic)

Mimic.copy(BB.PubSub)
Mimic.copy(BB.Safety)

defmodule BB.Reactor.SubscribeNotifier do
  @moduledoc """
  Stubs `BB.PubSub.subscribe` to tell the test once a subscription is in
  place, so a test can publish without racing the subscriber.

  Requires global Mimic mode, since the subscriber runs in a reactor step.
  """

  def notify_on_subscribe(test_pid \\ self()) do
    Mimic.stub(BB.PubSub, :subscribe, fn robot, path ->
      subscribe_and_notify(test_pid, path, [robot, path])
    end)

    Mimic.stub(BB.PubSub, :subscribe, fn robot, path, opts ->
      subscribe_and_notify(test_pid, path, [robot, path, opts])
    end)
  end

  defp subscribe_and_notify(test_pid, path, args) do
    result = Mimic.call_original(BB.PubSub, :subscribe, args)
    send(test_pid, {:subscribed, path})
    result
  end
end

ExUnit.start()
