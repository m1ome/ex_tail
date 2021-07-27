testfile = "testfile"
log_line = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n"
line_length = String.length(log_line)
lines = 100_000
IO.inspect("Single line length: #{line_length}")
IO.inspect("Full text length: #{line_length * lines}")

Enum.each(0..lines-1, fn _ ->
  File.write!(testfile, log_line, [:append])
end)

elapsed =
  :timer.tc(fn ->
    self_pid = self()

    {:ok, pid} = ExTail.start_link(file: testfile, interval: 0, chunk_size: 1000, fn: fn _lines, pos ->
      if pos >= 44600000, do: send(self_pid, {:finish, pos})
    end)

    receive do
      {:finish, pos} ->
        IO.puts "Stopped at position #{pos}"
        GenServer.stop(pid)
    end
  end)
  |> elem(0)

elapsed_ms = elapsed / 1_000
elapsed_se = elapsed / 1_000_000

IO.puts "ExTail reading #{lines/elapsed_se |> trunc()} pl/s [#{elapsed_ms |> trunc()} ms for #{lines} lines file]"

File.rm_rf!(testfile)
