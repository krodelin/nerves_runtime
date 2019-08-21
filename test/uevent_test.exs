defmodule UEventTest do
  use ExUnit.Case, async: false


  alias SystemRegistry, as: SR

  setup_all do
    Application.stop(:nerves_runtime)

    on_exit(
      fn ->
        Application.start(:nerves_runtime)
      end
    )
  end

  setup do
    {:ok, pid} = Nerves.Runtime.Kernel.UEvent.start_link()
    {:ok, pid: pid}
  end

  @root_message {
    "add",
    ["devices", "part1"],
    %{"key" => "root_value", "subsystem" => "block"}
  }
  @child_message  {
    "add",
    ["devices", "part1", "part2"],
    %{"key" => "child1_value", "subsystem" => "block"}
  }
  @conflict_message  {
    "add",
    ["devices", "part1", "key"],
    %{"key" => "child2_value", "subsystem" => "block"}
  }

  test "root device *without* child device has only binary properties", state do
    # Coming from a udev background one might assume that all properties are strings.
    # This is only true for root devices w/o children.
    send_uevent(@root_message, state)
    SR.match(:_)[:state]["devices"]["part1"]
    |> Enum.all?(fn {_, value} -> is_binary(value) end)
    |> assert
  end

  test "parent device has only binary properties", state do
    # Coming from a udev background one might assume that all properties are strings.
    # This is false parent devices.
    # They contain non-property keys named after the child dev path element whose values are the child properties.
    send_uevent(@root_message, state)
    send_uevent(@child_message, state)
    SR.match(:_)[:state]["devices"]["part1"]
    |> Enum.all?(fn {_, value} -> is_binary(value) end)
    |> assert
  end

  test "parent device properties remain stable after adding a child", state do
    # IF a (direct) child device's devpath part is the same as an existing property in the parent
    # AND the child is added after the parent
    # THEN the parent key property will be overwritten.
    send_uevent(@root_message, state)
    assert SR.match(:_)[:state]["devices"]["part1"]["key"] == "root_value"
    send_uevent(@conflict_message, state)
    assert SR.match(:_)[:state]["devices"]["part1"]["key"] == "root_value"
  end

  test "child device accessible after parent device as been added ", state do
    # IF a (direct) child device's devpath part is the same as an existing property in the parent
    # AND the parent  is added after the child
    # THEN the child(ren) are replaced by the parent property
    send_uevent(@conflict_message, state)
    assert SR.match(:_)[:state]["devices"]["part1"]["key"] == %{"key" => "child2_value", "subsystem" => "block"}
    send_uevent(@root_message, state)
    assert SR.match(:_)[:state]["devices"]["part1"]["key"] == %{"key" => "child2_value", "subsystem" => "block"}
  end

  defp send_uevent(message, state) do
    pid = state[:pid]
    port = :sys.get_state(pid).port
    binary = :erlang.term_to_binary(message)
    send(pid, {port, {:data, binary}})
    Process.sleep(1000) # Not nice but necessary to (try to) guarantee that changes have been applied to SystemRegistry
  end

end
