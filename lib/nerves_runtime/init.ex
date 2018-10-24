defmodule Nerves.Runtime.Init do
  use Task, restart: :transient

  alias __MODULE__

  def start_link(_) do
    Task.start_link(__MODULE__, :run, [])
  end

  def run() do
    Init.ApplicationPartition.run()
    Init.PrivDir.run()
  end
end
