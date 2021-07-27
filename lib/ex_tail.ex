defmodule ExTail do
  @moduledoc """
  ExTail implements a simple file tail functionality with a ability to record position.

  ## Usage
    {:ok, pid} = ExTail.start_link("test.txt", fn: &IO.inspect(&1), interval: 1000)
    GenServer.stop(pid)
  """

  use GenServer

  @default_interval 1_000
  @default_chunk_size 1_000

  @type state() :: %{
          :pos => integer(),
          :file_path => String.t(),
          :file => IO.device(),
          :interval => integer(),
          :chunk_size => integer(),
          :func => fun()
        }

  @spec init(keyword()) :: {:ok, state()} | {:stop, binary()}
  def init(opts) do
    func = Keyword.get(opts, :fn, &IO.puts/1)
    pos = Keyword.get(opts, :pos, 0)
    interval = Keyword.get(opts, :interval, @default_interval)
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    file_path = Keyword.get(opts, :file)

    with {:file?, file_path} when file_path != nil <- {:file?, file_path},
         {:ok, file} <- :file.open(file_path, [:raw]),
         {:ok, _} <- :file.position(file, pos) do
      {
        :ok,
        %{
          pos: pos,
          file_path: file_path,
          file: file,
          chunk_size: chunk_size,
          func: func,
          interval: interval
        },
        {:continue, :launch_tick}
      }
    else
      {:file?, nil} -> {:stop, "please provide :file in options"}
      {:error, reason} -> {:stop, "error straring ExTail #{inspect(reason)}"}
    end
  end

  @spec start_link(String.t(), keyword()) :: GenServer.on_start()
  def start_link(filename, opts \\ []) do
    GenServer.start_link(__MODULE__, Keyword.put(opts, :file, filename))
  end

  @spec info(pid()) :: state()
  def info(pid), do: GenServer.call(pid, :info)

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_continue(:launch_tick, state) do
    Process.send_after(self(), :tick, 0)
    {:noreply, state}
  end

  def handle_info(:tick, %{interval: interval} = state) do
    result = read(state)
    Process.send_after(self(), :tick, interval)

    case result do
      :ok -> {:noreply, state}
      {:error, reason} -> {:stop, "error reading file #{inspect(reason)}", state}
    end
  end

  defp read(%{
         file: file,
         chunk_size: chunk_size,
         func: func
       }),
       do: read_lines(file, func, chunk_size)

  defp read_lines(file, func, limit), do: read_lines(file, func, [], 0, limit)

  defp read_lines(_, _, [], iter, limit) when iter >= limit, do: :ok

  defp read_lines(file, func, lines, iter, limit) when iter >= limit do
    case :file.position(file, :cur) do
      {:ok, new_pos} ->
        lines
        |> Enum.reverse()
        |> func.(new_pos)

        :ok

      {:error, _} = error ->
        error
    end
  end

  defp read_lines(file, func, lines, iter, limit) do
    case :file.read_line(file) do
      {:ok, line} ->
        line =
          line
          |> to_string()
          |> String.trim_trailing()

        read_lines(file, func, [line | lines], iter + 1, limit)

      :eof ->
        read_lines(file, func, lines, 0, 0)

      {:error, _} = error ->
        error
    end
  end
end
