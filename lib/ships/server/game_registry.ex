defmodule Ships.Server.GameRegistry do
  @moduledoc false
  use GenServer

  def whereis_name(game_id) do
    GenServer.call(__MODULE__, {:whereis_name, game_id})
  end

  def register_name(game_id, pid) do
    GenServer.call(__MODULE__, {:register_name, game_id, pid})
  end

  def unregister_name(game_id) do
    GenServer.cast(__MODULE__, {:unregister_name, game_id})
  end

  def send(game_id, message) do
    case whereis_name(game_id) do
      :undefined ->
        {:badarg, {game_id, message}}

      pid ->
        Kernel.send(pid, message)
        pid
    end
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_) do
    {:ok, Map.new()}
  end

  def handle_call({:whereis_name, game_id}, _from, state) do
    {:reply, Map.get(state, game_id, :undefined), state}
  end

  def handle_call({:register_name, game_id, pid}, _from, state) do
    case Map.get(state, game_id) do
      nil ->
        Process.monitor(pid)
        {:reply, :yes, Map.put(state, game_id, pid)}

      _ ->
        {:reply, :no, state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _}, state) do
    {:noreply, remove_pid(state, pid)}
  end

  def handle_cast({:unregister_name, game_id}, state) do
    {:noreply, Map.delete(state, game_id)}
  end

  defp remove_pid(state, pid_to_remove) do
    remove = fn {_key, pid} -> pid != pid_to_remove end
    Enum.filter(state, remove) |> Enum.into(%{})
  end
end
