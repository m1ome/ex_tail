# ExTail
> Simple tailer with position handling for Elixir.

# Usage
```elixir
{:ok, pid} = ExTail.start_link("test.txt", fn: &IO.inspect(&1), interval: 1000)
GenServer.stop(pid)
```

## Installation

```elixir
def deps do
  [
    {:ex_tail, "~> 0.1.0"}
  ]
end
```
