# nerves uevent notes
nerves uses [SystemRegistry](https://github.com/nerves-project/system_registry) to store all device data provided by Linux using the uevent mechanism. The data passes several modules/functions changes it's format from a raw C representation to something more Erlang like to a format used by System Registry.
## uevent.c
‌​[uevent.c](https://github.com/nerves-project/nerves_runtime/blob/7eb6af701a46fb0cd9090f7389ab381f934fd7bf/src/uevent.c) handles raw uevents in the form of `action@devpath\0ACTION=action\0DEVPATH=devpath\0KEY=value\0` (see [uevent.c code](https://github.com/nerves-project/nerves_runtime/blob/7eb6af701a46fb0cd9090f7389ab381f934fd7bf/src/uevent.c#L148-L156)). uevent.c translates this to the Erlang tuple `{action, devpath, kv_map}`.

`action` is a string and can be:
-   `"add"`  
-   `"remove"`    
-   `"move"`    
-   others

`devpath` is an array of path elements. E.g.:

```elixir
["devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",  "musb-hdrc.1",
	"usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",  "0:0:0:0",  "block",  "sda"]
```

`kv_map` is a Key Value map with properties of the device. E.g.:

```elixir
%{"devname"  =>  "sda",  "devtype"  =>  "disk",  "major"  =>  "8",  "minor"  =>  "0",
	"subsystem"  =>  "block"}
```
‌
## uevent.ex

## handle_info/2

​[uevent.ex](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex) receives the Erlang tuple `{action, devpath, kv_map}` in [handle_info](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L45-L49) and forwards it to its `registry/4`functions. Please note that it prepands an :state to the devpath array (in preparation for it's intended SystemRegistry use). E.g.:

```elixir
["devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",  "musb-hdrc.1",
	"usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",  "0:0:0:0",  "block",  "sda"]
```
becomes
```elixir
[:state,  "devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",  "musb-hdrc.1",
	"usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",  "0:0:0:0",  "block",  "sda"]
```
when sent to registry/4.

## registry/4

`registry/4` uses pattern matching on the action to diffrentiate four cases:

-   ​[`"add"`](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L51): A device has been added
- ​[`"remove"`](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L71): A device has been removed   
-   ​[`"move"`](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L84): A Device has been moved   
-   ​[`_`](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L91): Default - Do Nothing
    
If `kv_map` contains a `"subsystem"` key the devpath array is added to SystemRegistry under the [`subsystem_scope`](https://github.com/nerves-project/nerves_runtime/blob/ae507f5e40cc25d36f9259d5f220a4f2b49f0dcc/lib/nerves_runtime/kernel/uevent.ex#L103) `[:state, "subystems", SUBSYSTEM_VALUE]`. The `kv_map` is also added to the SystemRegistry using the `devpath` (a.k.a. "scope") as keypath.

# Example

## handle_info/2

`handle_info/2` recieves the following Tuple from the uevent.ex Port:
```elixir
{
	"add",
	["devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",  "musb-hdrc.1",
		"usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",  "0:0:0:0",  "block",  "sda"],
	%{"devname"  =>  "sda",  "devtype"  =>  "disk",  "major"  =>  "8",  "minor"  =>  "0",
		"subsystem"  =>  "block"}
} 
```
‌It prepend the device path array with `:state` and calls `registry/4`.

## registry/4

`registry/4` checks if `kv_map` includes the `"subsystem"` key and if so adds the dev_path to the subsystem_scope in System Registry:
```elixir
%{
	state:  %{
		“subsystems”: %{
			“block”: [
				[:state,  "devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",
					"musb-hdrc.1",  "usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",
					"0:0:0:0", "block",  "sda"],
			]
		}
	}
}
```
‌
Next it uses the `devpath` as keypath to add the `kv_map` to System Registry:
```elixir
%{
	state:  %{
		“subsystems”: %{
			“block”: [
				[:state,  "devices",  "platform",  "ocp",  "47400000.usb",  "47401c00.usb",
					"musb-hdrc.1",  "usb1",  "1-1",  "1-1:1.0",  "host0",  "target0:0:0",
					"0:0:0:0", "block",  "sda"],
			]
		},
		"devices": %{
			"platform": %{
				"ocp": %{
					"47400000.usb": %{
						"47401c00.usb": %{
							"musb-hdrc.1": %{
								"usb1": %{
									"1-1": %{
										"1-1:1.0": %{
											"host0": %{
												"target0:0:0": %{
													"0:0:0:0": %{
														"block": %{
															"sda": %{"devname"  =>  "sda",
																"devtype"  =>  "disk",
																"major"  =>  "8",
																"minor"  =>  "0",
																"subsystem"  =>  "block"}
														}
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}
```

# ‌(Possible) Problems

## No "flat" maps

Coming from a udev background one might assume that all properties are strings.
This is false parent devices.
They contain non-property keys named after the child dev path element whose values are the child properties.
    
## Name clash

IF a (direct) child device's devpath part is the same as an existing property in the parent
AND the child is added after the parent
THEN the parent key property will be overwritten.
    
IF a (direct) child device's devpath part is the same as an existing property in the parent
AND the parent  is added after the child
THEN the child(ren) are replaced by the parent property