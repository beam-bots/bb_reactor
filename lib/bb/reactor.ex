# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

defmodule BB.Reactor do
  @moduledoc """
  Spark DSL extension for integrating Reactor with BB robotics framework.

  This extension provides `command`, `wait_for_event`, and `wait_for_state`
  entities that simplify building robot operation sequences with proper safety
  handling and compensation.

  ## Usage

  ```elixir
  defmodule MyRobot.PickAndPlace do
    use Reactor, extensions: [BB.Reactor]

    input :pick_pose
    input :place_pose

    command :approach do
      command :move_to_pose
      argument :target, input(:pick_pose)
    end

    command :grip do
      command :close_gripper
      wait_for :approach
    end

    command :retreat do
      command :move_to_pose
      argument :target, input(:place_pose)
      wait_for :grip
      compensate :return_home
    end

    return :retreat
  end
  ```

  ## Running a Reactor

  Reactors using this extension must be run with the robot module in context:

  ```elixir
  Reactor.run(MyRobot.PickAndPlace, inputs, %{private: %{bb_robot: MyRobot}})
  ```

  ## Entities

  - `command` - Execute a BB command with safety handling and compensation support
  - `wait_for_event` - Wait for a PubSub event matching a pattern
  - `wait_for_state` - Wait for the robot to reach a specific state
  """

  alias BB.Reactor.Dsl

  @command Dsl.Command.__entity__()
  @wait_for_event Dsl.WaitForEvent.__entity__()
  @wait_for_state Dsl.WaitForState.__entity__()

  use Spark.Dsl.Extension,
    sections: [],
    transformers: [Dsl.Transformer],
    dsl_patches: [
      %Spark.Dsl.Patch.AddEntity{
        section_path: [:reactor],
        entity: @command
      },
      %Spark.Dsl.Patch.AddEntity{
        section_path: [:reactor],
        entity: @wait_for_event
      },
      %Spark.Dsl.Patch.AddEntity{
        section_path: [:reactor],
        entity: @wait_for_state
      }
    ]
end
