defmodule ExperimentManager.Application do
  use Application

  @impl true
  def start(_type, _args) do
    Logger.add_handlers(:experiment_manager)
    topologies = [
      example: [
        strategy: Cluster.Strategy.Gossip
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: ExperimentManager.ClusterSupervisor]]},
      {DynamicSupervisor, name: ExperimentManager.StewardSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: ExperimentManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
