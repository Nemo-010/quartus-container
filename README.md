# Quartus for eYRC Logic Quest

A container image with Quartus Prime, ModelSim and Cyclone device data — the
three things the eYRC Logic Quest theme needs — that runs with one command on
a Mac or on Linux.

```sh
podman run --rm -it -v "$PWD:/work" ghcr.io/nemo-010/quartus-container:latest
```

## What Logic Quest needs, and what is in here

From the theme's own requirements (eYRC 2025-26 portal):

| Requirement | In the image |
|---|---|
| Quartus Prime | yes, with `quartus_map`/`fit`/`asm`/`sta` |
| ModelSim | yes, Questa Intel FPGA Starter Edition (`vsim`) |
| Cyclone device support for the DE0-Nano | yes, `cyclone` device data; `cycloneive` and `cycloneivgx` devinfo present |
| x86_64, 4+ cores, 8 GB RAM, 100 GB SSD | the image is x86_64; give the container enough RAM |

The DE0-Nano is a Cyclone IV E part. Note the exact device name: Quartus's
Cyclone IV E list contains `EP4CE22F17C6`, not `EP4CE22F17C6N`. The build
workflow asks Quartus for the family's part list and synthesises a small
design for a real part from it, then checks a `.sof` was produced. So "it
works" means a bitstream came out, not that the tools started.

## On a Mac

The image is amd64 because Quartus is x86-64 only. Podman's macOS machine
already ships `qemu-user-static-x86` and registers binfmt, so the amd64 image
runs on the arm64 VM with no configuration. Emulation is slower than native
x86-64; expect synthesis to take noticeably longer than on a PC.

## Build it yourself

```sh
podman build -f Containerfile -t quartus .
```

Build args:

| Arg | Default | Meaning |
|---|---|---|
| `DEVICES` | `cyclone` | comma-separated families, e.g. `cyclone,cyclonev,max10` |
| `WITH_QUESTA` | `1` | set to `0` to skip ModelSim (saves ~3.3 GB) |
| `QUARTUS_VERSION` | `25.1std.0.1129` | Altera installer version |
| `BASE_IMAGE` | `debian:stable-slim` | base image |

Smaller image without simulation:

```sh
podman build --build-arg WITH_QUESTA=0 -t quartus .
```

## Sizes, so there are no surprises

| Piece | Size |
|---|---|
| Quartus Lite installer | ~2.0 GB |
| Questa / ModelSim installer | ~3.3 GB |
| Cyclone device data | ~0.5 GB |

The image is several GB. That is Quartus, not the packaging.

## Using it

Inside the container:

```sh
quartus_sh --version
quartus_map --version
vsim -version
```

A minimal synthesis run:

```sh
quartus_sh -t synth.tcl     # project + device assignments
quartus_sh -t build.tcl     # execute_flow -compile
```

See `.github/workflows/quartus.yml` for a complete working example. It
produced `blinky.sof` for `EP4CE22F17C6` both natively and under emulation.

## Notes

- Quartus needs a licence for some devices. The free Lite edition covers
  Cyclone IV E, which is what the DE0-Nano uses.
- The USB Blaster for programming the board needs `--device` access and udev
  rules on the host; that is outside the container.
- Emulation is fine for correctness. For large designs on a Mac, native x86-64
  is much faster.
