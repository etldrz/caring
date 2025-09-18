defmodule Experimentwizard.Master do
  @moduledoc """
  This modulde creates and manages experiment interfaces.
  """
  use GenServer
  ############# Client side code #############

  def start_link(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
    children = [
      {DynamicSupervisor, name: MasterManager}
    ]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  @doc """
  Adds an experimental interface.
  """
  def get_experiment_interface(name) do
    GenServer.call(__MODULE__, {:new, name})
  end

  @doc """
  Returns all current experiment interfaces.
  """
  def get_all_experiment_interfaces() do
    GenServer.call(__MODULE__, :get_all)
  end

  @doc """
  Delete the given experiment interface. If it doesn't exist then does nothing
  """
  def delete_experiment_package(name) do
    GenServer.call(__MODULE__, {:delete, name})
  end

  ############# Server side code (callbacks) #############
  @impl true
  def init(_init_arg) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({:new, name}, _from, state) do
    atom_name = String.to_atom(name)
    # Since we're lauching different instances of the same module, we must guarantee the keys are unique.
    if Map.get(state, atom_name) != nil do
      {:reply, %{atom_name => "Duplicated Name! Please try a different name!"}, state}
    else
      child =
        %{
        id: name,
        start: {Experimentwizard.Manager, :start_link, [[], atom_name]}
      }
      {:ok, eManager} = DynamicSupervisor.start_child(MasterManager, child)
      updated_state = Map.put(state, atom_name, eManager)
      {:reply, eManager, updated_state}
    end
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:delete, name}, _from, state) do
    updated_state = Map.delete(state, name)
    {:reply, updated_state, updated_state}
  end

end
