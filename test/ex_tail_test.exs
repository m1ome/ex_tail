defmodule ExTailTest do
  use ExUnit.Case, async: false
  doctest ExTail

  @testfile Path.absname("testfile")

  setup do
    File.write!(@testfile, "")

    on_exit(fn ->
      File.rm_rf!(@testfile)
    end)

    :ok
  end

  describe "options validation" do
    test "it should fail on missing file path" do
      Process.flag(:trap_exit, true)
      ExTail.start_link(nil)

      assert_receive {:EXIT, _, "please provide :file in options"}
    end

    test "it should parse options corretly" do
      {:ok, pid} =
        ExTail.start_link(@testfile,
          pos: 100,
          fn: &IO.warn/1,
          interval: 500,
          chunk_size: 10_000
        )

      info = ExTail.info(pid)
      assert info.chunk_size == 10_000
      assert info.file_path == @testfile
      assert info.interval == 500
      assert info.pos == 100
      assert info.func == (&IO.warn/1)

      GenServer.stop(pid)
    end
  end

  test "basic test with single line" do
    File.write!(@testfile, "Default log test line\n")

    pid = self()
    func = fn line, _ -> send(pid, {:new_line, line}) end
    {:ok, pid} = ExTail.start_link(@testfile, fn: func)

    assert_receive {:new_line, ["Default log test line"]}

    GenServer.stop(pid)
  end

  test "basic test with multiple lines" do
    File.write!(
      @testfile,
      "Default log test line 1\nDefault log test line 2\nDefault log test line 3\n"
    )

    pid = self()
    func = fn line, _ -> send(pid, {:new_line, line}) end
    {:ok, pid} = ExTail.start_link(@testfile, fn: func)

    assert_receive {:new_line,
                    [
                      "Default log test line 1",
                      "Default log test line 2",
                      "Default log test line 3"
                    ]}

    GenServer.stop(pid)
  end
end
