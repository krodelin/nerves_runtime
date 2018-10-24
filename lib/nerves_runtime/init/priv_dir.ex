defmodule Nerves.Runtime.Init.PrivDir do
  alias Nerves.Runtime.KV

  def run() do
    prefix = "nerves_fw_application_part0"
    devpath = KV.get_active("#{prefix}_devpath")
    destination = Path.join([devpath, "nerves_runtime", "init"])

    unless File.dir?(destination) do
      copy_priv_dirs(destination)
    end
  end

  defp copy_priv_dirs(destination) do
    File.mkdir_p(destination)
    Path.wildcard("#{:code.lib_dir}/*/priv")
    |> Enum.each(fn(source) ->
      lib = parse_lib(source)

      ebin_path = Path.join([destination, lib, "ebin"])
      priv_path = Path.join([destination, lib, "priv"])
      File.mkdir_p(ebin_path)
      File.mkdir_p(priv_path)
      File.cp_r(source, priv_path)
      Code.prepend_path(ebin_path)
    end)
  end

  defp parse_lib(path) do
    [_, lib | _] =
      Path.split(path)
      |> Enum.reverse

    [lib | _] = String.split(lib, "-")

    lib
  end
end
