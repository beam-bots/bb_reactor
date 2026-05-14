# SPDX-FileCopyrightText: 2026 James Harton
#
# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.BbReactor.Install do
    @shortdoc "Installs BB.Reactor into a project"
    @moduledoc """
    #{@shortdoc}

    Composes `reactor.install` and `spark.install` so that the Reactor formatter
    rules and the `Spark.Formatter` plugin are both configured.

    ## Example

    ```bash
    mix igniter.install bb_reactor
    ```
    """

    use Igniter.Mix.Task

    @impl Igniter.Mix.Task
    def info(_argv, _parent) do
      %Igniter.Mix.Task.Info{
        composes: ["reactor.install", "spark.install"]
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      igniter
      |> Igniter.compose_task("reactor.install", [])
      |> Igniter.compose_task("spark.install", [])
    end
  end
else
  defmodule Mix.Tasks.BbReactor.Install do
    @shortdoc "Installs BB.Reactor into a project"
    @moduledoc false
    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The bb_reactor.install task requires igniter. Please install igniter and try again.

          mix igniter.install bb_reactor
      """)

      exit({:shutdown, 1})
    end
  end
end
