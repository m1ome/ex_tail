defmodule ExTail do
  @moduledoc """
  Documentation for `ExTail`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> ExTail.hello()
      :world

  """

  use GenServer

  @default_interval 1_000
  @default_chunk_size 1_000

  @type state() :: %{
          :pos => integer(),
          :file_path => String.t(),
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

    if file_path == nil,
      do: {:stop, "please provide :file in options"},
      else:
        {:ok,
         %{
           pos: pos,
           file_path: file_path,
           chunk_size: chunk_size,
           func: func,
           interval: interval
         }}
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec info(pid()) :: state()
  def info(pid), do: GenServer.call(pid, :info)

  def handle_call(:info, _from, state) do
    {:reply, state, state}
  end

  def handle_info(:tick, state) do
    case read(state) do
      {:ok, new_position} -> {:noreply, %{state | pos: new_position}}
      {:error, reason} -> {:stop, "error reading file #{inspect(reason)}", state}
    end
  end

  defp read(%{
         file_path: file_path,
         pos: pos,
         chunk_size: chunk_size,
         func: func
       }) do
    with {:ok, file} <- :file.open(file_path, [:read]),
         {:ok, _} <- :file.position(file, pos),
         :ok <- read_lines(file, func, chunk_size),
         {:ok, cur_position} <- :file.position(file, :cur),
         do: {:ok, cur_position}
  end

  defp read_lines(file, func, limit), do: read_lines(file, func, 0, limit)
  defp read_lines(_, _, iter, limit) when iter >= limit, do: :ok

  defp read_lines(file, func, iter, limit) do
    case :file.read_line(file) do
      {:ok, line} ->
        func.(line)
        read_lines(file, iter + 1, limit)

      :eof ->
        :ok

      {:error, _} = error ->
        error
    end
  end
end
