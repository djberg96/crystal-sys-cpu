# crystal-sys-cpu

A Crystal port of my `sys-cpu` Ruby library that exposes CPU details under `System::CPU`.

## Status

This first Crystal port currently includes:

- Linux support via `/proc/cpuinfo`, `/proc/stat`, and `/proc/loadavg`
- macOS support via native libc and Mach calls, with a small `system_profiler` fallback for model names

Windows and the broader BSD/Solaris surface from the Ruby gem are not ported yet.

## Installation

Add this shard to your `shard.yml`:

```yaml
dependencies:
  system-cpu:
    path: ../crystal-sys-cpu
```

Then require it:

```crystal
require "system-cpu"
```

## Usage

```crystal
require "system-cpu"

pp System::CPU.load_avg
pp System::CPU.model
pp System::CPU.num_cpu
pp System::CPU.cpu_usage(sample_time: 0.1, samples: 2)
```

On Linux, `System::CPU.processors` returns parsed `/proc/cpuinfo` entries:

```crystal
System::CPU.processors.each do |cpu|
  cpu.members.each do |member|
    puts "#{member}: #{cpu[member]}"
  end
end
```

Processor records also support dynamic zero-argument attribute access for Linux fields:

```crystal
first = System::CPU.processors.first
pp first.model_name
pp first.vendor_id
```

## Notes

- `System::CPU` is a module instead of a class, which fits Crystal better and avoids colliding with Crystal's existing `System` namespace.
- On macOS, `freq` returns `nil` if the platform does not expose CPU frequency through the available system APIs.

## Author
Daniel J. Berger
