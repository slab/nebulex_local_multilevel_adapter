# Start Telemetry
_ = Application.start(:telemetry)

# Set nodes
nodes = [:"node1@127.0.0.1", :"node2@127.0.0.1"]
:ok = Application.put_env(:nebulex, :nodes, nodes)

# Nebulex dependency path
nbx_dep_path = Mix.Project.deps_paths()[:nebulex]

for file <- File.ls!("#{nbx_dep_path}/test/support"), file != "test_cache.ex" do
  Code.require_file("#{nbx_dep_path}/test/support/" <> file, __DIR__)
end

for file <- File.ls!("#{nbx_dep_path}/test/shared/cache") do
  Code.require_file("#{nbx_dep_path}/test/shared/cache/" <> file, __DIR__)
end

for file <- File.ls!("#{nbx_dep_path}/test/shared"), file != "cache" do
  Code.require_file("#{nbx_dep_path}/test/shared/" <> file, __DIR__)
end

# Load shared tests
for file <- File.ls!("test/shared"), not File.dir?("test/shared/" <> file) do
  Code.require_file("./shared/" <> file, __DIR__)
end

# Spawn remote nodes
unless :clustered in Keyword.get(ExUnit.configuration(), :exclude, []) do
  Nebulex.Cluster.spawn(nodes)
end

ExUnit.start()
