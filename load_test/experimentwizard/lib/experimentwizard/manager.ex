defmodule Experimentwizard.Manager do
  @moduledoc """
  This module provides functions to manage an experiment within
  an experiment interface.
  """
  use GenServer

  ############# Client side code #############
  def start_link(arg) do
    GenServer.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def start_link(arg, name) do
    GenServer.start_link(__MODULE__, arg, name: name)
  end

  @doc """
  Return all the content of the current experiment interface.
  """
  def get_current_interface_state(server) do
    GenServer.call(server, :get)
  end

  @doc """
  Add a new experiment to the given experiment interface.
  If the experiment already exists, do nothing.
  """
  def experiment(server, name) do
    GenServer.call(server, {:add_experiment_name, name})
    server
  end

  @doc """
  Adds new credentials to the given experiment in the desired experiment interface.
  """
  def credentials(server, experiment, credentials) do
    GenServer.call(server, {:add_credentials, experiment, credentials})

    server
  end

  @doc """
  Add a new project name to the given experiment in the desired experiment interface.
  """
  def project(server, experiment, name) do
    GenServer.call(server, {:add_project_name, experiment, name})
    server
  end

  @doc """
  Add a new profile name to the given experiment in the desired experiment interface.
  """
  def profile(server, experiment, name) do
    GenServer.call(server, {:add_profile_name, experiment, name})
    server
  end

  @doc """
  Try starting the experiment with in the given experiment interface.
  The starting parameters should be defined in the interface.
  """
  def start_experiment(server, experiment) do
    # Time out after 15 minutes
    GenServer.call(server, {:start_experiment, experiment}, 900_000)
  end

  @doc """
  Try terminate the given experiment in the given experiment interface.
  """
  def terminate_experiment(server, experiment) do
    GenServer.call(server, {:terminate_experiment, experiment}, 30_000)
  end

  @doc """
  Get the manifest of the given experiment in the desired experiment interface.
  """
  def manifest(server, experiment) do
    GenServer.call(server, {:get_manifest, experiment}, 30_000)
  end

  @doc """
  Get the experiment status of the given experiment in the desired experiment interface.
  """
  def experiment_status(server, experiment) do
    GenServer.call(server, {:get_experiment_status, experiment}, 10_000)
  end

  @doc """
  Get the executers of the given experiment in the desired experiment interface.
  """
  def executer(server, experiment) do
    GenServer.call(server, {:get_executer, experiment}, 10_000)
  end

  @doc """
  Try connect to an experiment.
  If successful, the manifest and the executer of current interface will be overwritten.
  If connect_others_experiment is set to true, this function will try to connect to
  other people's experiment.
  If the user's credential does not have enough access and still tries to connect to
  other people's experiment, it WILL NOT overwrite the manifest and executer.
  """
  def connect_experiment(server, experiment, connect_others_experiment) do
    GenServer.call(server, {:connect_experiment, experiment, connect_others_experiment}, 30_000)
  end

  @doc """
  Try connect to an experiment. If the experiment doesn't exist, try start the experiment.
  """
  def connect_or_start(server, experiment) do
    GenServer.call(server, {:connect_or_start, experiment}, 900_000)
  end

  ############# Server side code (callbacks) #############
  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  # Handle call to get all experiment packages.
  @impl true
  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call({:add_experiment_name, experiment_name}, _from, state) do
    updated_state = Map.put_new(state, experiment_name,
    %{
      credentials: %{},
      manifest: [],
      project: "",
      experiment: experiment_name,
      profile: "",
      executer: nil,
      orchestrator: nil
    })
    {:reply, updated_state, updated_state}
  end

  # Handle call to add credentials to an existing experiment package, if such experiment package doesn't exist
  # it returns the current state
  # Assuming the passed-in credentials is a map of path containing credentials
  @impl true
  def handle_call({:add_credentials, experiment, credentials}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      experiment_map = Map.update!(experiment_map, :credentials, fn _value -> credentials end)
      updated_state = Map.update!(state, experiment, fn _value -> experiment_map end)
      {:reply, updated_state, updated_state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:add_project_name, experiment, project_name}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      experiment_map = Map.update!(experiment_map, :project, fn _value -> project_name end)
      updated_state = Map.update!(state, experiment, fn _value -> experiment_map end)
      {:reply, updated_state, updated_state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:add_profile_name, experiment, profile_name}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      experiment_map = Map.update!(experiment_map, :profile, fn _value -> profile_name end)
      updated_state = Map.update!(state, experiment, fn _value -> experiment_map end)
      {:reply, updated_state, updated_state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_executer, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    {:reply, Map.get(experiment_map, :executer), state}
  end

  @impl true
  def handle_call({:start_experiment, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment != nil do
      new_experiment_map = start_exp(experiment_map)
      new_state = Map.update!(state, experiment, fn _value -> new_experiment_map end)
      {:reply, new_state, new_state}
    else
      {:reply, "Experiment doesn't exist!", state}
    end
  end

  @doc """
  Terminate the experiment, since the experiment is terminated,
  the experiment pacakge is re-initialized for future use.
  """
  @impl true
  def handle_call({:terminate_experiment, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    result = Portalapi.terminate_experiment(
      experiment_map.credentials,
      experiment_map.project,
      experiment_map.experiment
    )
    updated_map =
    %{
      credentials: %{},
      manifest: [],
      experiment: experiment,
      project: "",
      profile: "",
      executer: nil,
      orchestrator: nil
    }
    updated_state = Map.update!(state, experiment, fn _value -> updated_map end)
    {:reply, result, updated_state}
  end

  @impl true
  def handle_call({:get_manifest, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      result = Portalapi.get_manifest(
        experiment_map.credentials,
        experiment_map.project,
        experiment_map.experiment
      )
      {:reply, result, state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:get_experiment_status, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      result = Portalapi.get_experiment_status(
        experiment_map.credentials,
        experiment_map.project,
        experiment_map.experiment
      )
      {:reply, result, state}
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:connect_experiment, experiment, connect_others_experiment}, _from, state) do
    # Override the experiment manifest information and executer information
    experiment_map = Map.get(state, experiment)
    if experiment_map != nil do
      if connect_others_experiment || check_experiment_ownership(experiment_map) do
        updated_map = update_info(experiment_map)
        updated_state = Map.update!(state, experiment, fn _value -> updated_map end)
        {:reply, updated_state, updated_state}
      else
        {:reply, "You don't own this experiment or this experiment doesn't exist!", state}
      end
    else
      {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:connect_or_start, experiment}, _from, state) do
    experiment_map = Map.get(state, experiment)
    result = Portalapi.get_experiment_status(
      experiment_map.credentials,
      experiment_map.project,
      experiment_map.experiment
    )
    if !is_map(result) do
      updated_map = start_exp(experiment_map)
      updated_state = Map.update!(state, experiment, fn _value -> updated_map end)
      {:reply, updated_state, updated_state}
    else
      updated_map = update_info(experiment_map)
      updated_state = Map.update!(state, experiment, fn _value -> updated_map end)
      {:reply, updated_state, updated_state}
    end
  end

  ############# Private Helper Functions #############
  defp update_info(state) do
    manifest = Portalapi.is_experiment_ready(
      state.credentials,
      state.project,
      state.experiment
    )
    updated_state = Map.update!(state, :manifest, fn _value -> manifest end)
    executers = Enum.map(manifest, fn x ->
      # Get node name
      # Need to downcase the strings since the way IEX starts the nodes are lower case characters
      ("executer@" <>(elem(x, 0) |> to_string())) |> String.downcase() |> String.to_atom()
    end)
    half_name = state.project <> state.experiment
    children = [
      {Experimentwizard.Executer, [executers, half_name]},
      {Experimentwizard.Orchestrator, half_name}
    ]
    control_name = String.to_atom(half_name <> "controller")
    Supervisor.start_link(children, [strategy: :one_for_one, name: control_name])
    updated_state = Map.update!(updated_state, :executer, fn _value -> executers end)
    Map.update!(updated_state, :orchestrator, fn _value -> half_name <> "Orchestrator" end)
  end

  # Probably need to change in the future since there might be multiple projects
  defp check_experiment_ownership(state) do
    submap = Portalapi.get_user_experiments(state.credentials)[state.project]
    cond do
      # First, check if the map has the key
      submap == nil -> false
      # Then check if the list has the targeted experiment.
      submap[state.project] |> Enum.find(fn x -> x == state.experiment end) == nil -> false
      true -> true
    end
  end

  defp start_exp(state) do
    result = Portalapi.start_experiment(
      state.credentials,
      state.profile,
      state.project,
      state.experiment
    )
    # If result is not 0, then there's something wrong
    if (result != 0) do
      state
    else
      update_info(state)
    end
  end
end
