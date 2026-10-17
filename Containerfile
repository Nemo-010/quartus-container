# Quartus Prime + ModelSim, ready for eYRC Logic Quest.
#
# Quartus is x86-64 Linux software, so this image is amd64. On Apple Silicon,
# Podman runs it through qemu-user emulation automatically (the Podman machine
# already ships qemu-user-static-x86 and registers binfmt). Nothing to set up.
#
# Includes what Logic Quest actually needs:
#   - Quartus Prime Lite with the synthesis and fitting engines
#   - Cyclone device data, for the DE0-Nano (Cyclone IV E, EP4CE22F17C6N)
#   - ModelSim / Questa for simulation
#
# Sizes are large: the core installer is ~2 GB, Questa ~3.3 GB, and the
# Cyclone device data ~0.5 GB.

ARG BASE_IMAGE=debian:stable-slim

FROM --platform=linux/amd64 ${BASE_IMAGE}

ARG QUARTUS_VERSION=25.1std.0.1129
ARG QUARTUS_URLDIR=25.1std/1129
# Device families to install. Cyclone covers Cyclone IV E (DE0-Nano).
ARG DEVICES=cyclone
# Set to 1 to include ModelSim/Questa (needed for Logic Quest simulation).
ARG WITH_QUESTA=1
ARG DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

# Libraries Quartus and Questa both need, plus the 32-bit runtime Questa uses.
RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl bzip2 unzip procps tzdata udev \
        libncurses6 libtinfo6 \
        libx11-6 libxext6 libxft2 libxrender1 libxi6 libxtst6 \
        libxau6 libxdmcp6 libsm6 libice6 \
        libfontconfig1 libfreetype6 libdbus-1-3 libexpat1 \
        libglib2.0-0 libpng16-16 zlib1g libnuma1 \
        libstdc++6 libgcc-s1 libc6-i386 \
        libx11-6:i386 libxext6:i386 libxft2:i386 libxrender1:i386 \
        libxi6:i386 libxtst6:i386 libxau6:i386 libxdmcp6:i386 \
        libsm6:i386 libice6:i386 libncurses6:i386 libtinfo6:i386 \
        libexpat1:i386 libfontconfig1:i386 libfreetype6:i386 \
        libglib2.0-0:i386 libpng16-16:i386 zlib1g:i386 libstdc++6:i386 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/quartus

# Fetch the installer, the device data and Questa, then install unattended.
# The installer looks for the .qdz files in its own directory, so they all have
# to be present before it runs.
RUN set -euo pipefail; \
    base="https://download.altera.com/akdlm/software/acdsinst/${QUARTUS_URLDIR}/ib_installers"; \
    file="QuartusLiteSetup-${QUARTUS_VERSION}-linux.run"; \
    curl -fL --retry 3 --retry-delay 2 -A "Alterabot/1.0" -o "${file}" "${base}/${file}"; \
    for fam in $(echo "${DEVICES}" | tr ',' ' '); do \
      curl -fL --retry 3 --retry-delay 2 -A "Alterabot/1.0" \
        -o "${fam}-${QUARTUS_VERSION}.qdz" "${base}/${fam}-${QUARTUS_VERSION}.qdz"; \
    done; \
    chmod +x "${file}"; \
    echo "installing Quartus"; \
    ./"${file}" \
        --mode unattended \
        --unattendedmodeui none \
        --accept_eula 1 \
        --installdir /opt/quartus \
        --disable-components questa_fse,quartus_help,quartus_update; \
    rm -f ./*.qdz; \
    rm -rf /tmp/quartus /opt/quartus/logs /opt/quartus/uninstall

# ModelSim / Questa, only when asked for.
RUN set -euo pipefail; \
    if [ "${WITH_QUESTA}" = "1" ]; then \
      base="https://download.altera.com/akdlm/software/acdsinst/${QUARTUS_URLDIR}/ib_installers"; \
      q="QuestaSetup-${QUARTUS_VERSION}-linux.run"; \
      curl -fL --retry 3 --retry-delay 2 -A "Alterabot/1.0" -o "${q}" "${base}/${q}"; \
      chmod +x "${q}"; \
      echo "installing Questa"; \
      ./"${q}" \
          --mode unattended \
          --unattendedmodeui none \
          --accept_eula 1 \
          --installdir /opt/quartus \
          --questa_edition questa_fse; \
      rm -f "${q}"; \
      rm -rf /opt/quartus/logs /opt/quartus/uninstall; \
    fi

# Quartus ships a launcher in bin/ that sources adm/qenv.sh, which refuses to
# run unless `uname -m` is x86_64 and /proc/cpuinfo mentions sse. Under
# emulation `uname -m` reports the host, so the launcher aborts even though the
# binaries are fine. Putting linux64 on PATH skips the launcher.
ENV QUARTUS_ROOTDIR=/opt/quartus/quartus
ENV LD_LIBRARY_PATH=/opt/quartus/quartus/linux64
ENV PATH=/opt/quartus/quartus/linux64:/opt/quartus/quartus/bin:/opt/quartus/questa_fse/bin:/usr/local/bin:/usr/bin:/bin
ENV LANG=C.UTF-8
ENV LM_LICENSE_FILE=/opt/quartus/questa_fse/licenses

WORKDIR /work

CMD ["/bin/bash"]
