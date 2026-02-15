### Attempt to follow the tutorial : https://chipyard.readthedocs.io/en/stable/VLSI/Sky130-OpenROAD-Tutorial.html


# ====================================================
# Stage 1 — Full Build Environment (up to build-setup)
# ====================================================

FROM ubuntu:22.04 AS base-builder

ENV DEBIAN_FRONTEND=noninteractive
ENV CONDA_DIR=/opt/conda
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8


# ---- Install base + build dependencies ----
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git curl wget ca-certificates \
    python3 python3-venv python3-pip \
    bzip2 unzip xz-utils \
    sudo openjdk-11-jdk scala git-lfs \
    locales device-tree-compiler universal-ctags \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8

# ---- Install Miniforge ----
RUN wget --quiet https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O /tmp/miniforge.sh && \
    bash /tmp/miniforge.sh -b -p ${CONDA_DIR} && \
    rm /tmp/miniforge.sh



ENV PATH="${CONDA_DIR}/bin:${PATH}"

# ---- Conda configuration ----
RUN conda config --set channel_priority true && \
    conda config --add channels defaults



# ---- Install PDK + Tools (single layer for cache efficiency) ----

RUN conda create -y -c litex-hub --prefix /root/.conda-sky130 open_pdks.sky130a=1.0.457_0_g32e8f23 && \
    conda create -y -c litex-hub --prefix /root/.conda-yosys yosys=0.27_4_gb58664d44 && \
    conda create -y -c litex-hub --prefix /root/.conda-openroad openroad=2.0_7070_g0264023b6 && \
    conda create -y -c litex-hub --prefix /root/.conda-klayout klayout=0.28.5_98_g87e2def28 && \
    conda create -y -c litex-hub --prefix /root/.conda-signoff magic=8.3.376_0_g5e5879c netgen=1.5.250_0_g178b172 && \
    conda clean -afy



RUN conda config --set channel_priority strict && \
    conda config --remove channels defaults



# ============================
# Stage 2 —  Build-Chipyard
# ============================

FROM base-builder AS chipyard-builder

SHELL ["/bin/bash", "-c"]

# ---- Clone Chipyard ----
RUN git clone https://github.com/ucb-bar/chipyard.git /root/chipyard && cd /root/chipyard && git checkout 1.13.0

## ---- Build setup ----
RUN cd /root/chipyard && ./scripts/build-setup.sh -v -s 6 -s 7 -s 8 -s 9 riscv-tools



# ====================
# Stage 2 —  Runtime
# ====================

FROM chipyard-builder AS runtime

ENV RISCV=/root/chipyard/.conda-env/riscv-tools
ENV PATH="/root/.conda-yosys/bin:/root/.conda-openroad/bin:/root/.conda-klayout/bin:/root/.conda-signoff/bin:${PATH}"


## ---- Clone SRAM macros ----
RUN git clone https://github.com/rahulk29/sram22_sky130_macros.git /root/sram22_sky130_macros
RUN git -C /root/sram22_sky130_macros checkout 1f20d16
RUN cd /root/sram22_sky130_macros && git lfs install --local && git lfs pull
RUN ls /root/sram22_sky130_macros

# Fail early if a required LEF is missing
RUN test -f /root/sram22_sky130_macros/sram22_64x24m4w24/sram22_64x24m4w24.lef

# ---- Initialize VLSI ----
RUN cd /root/chipyard && source env.sh && ./scripts/init-vlsi.sh sky130 openroad

ENTRYPOINT ["/bin/bash", "-lc", "sleep infinity"]
