# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Build HyPhy 3 from source (C++20 + OpenMP)
# ==============================================================================
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

COPY CMakeLists.txt /src/
COPY cmake/ /src/cmake/
COPY include/ /src/include/
COPY src/ /src/src/
COPY viz/ /src/viz/
COPY tests/ /src/tests
COPY benchmarks/ /src/benchmarks/

RUN cmake -S /src -B /build -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DHYPHY3_GIT_COMMIT=docker \
    && cmake --build /build \
    && strip /build/hyphy3 /build/hyphy3-*

RUN ctest --test-dir /build --output-on-failure

# ==============================================================================
# Stage 2: Minimal runtime image
# ==============================================================================
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libgomp1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/hyphy3 /usr/local/bin/
COPY --from=builder /build/hyphy3-* /usr/local/bin/

WORKDIR /data

# No ENTRYPOINT, so workflow engines (Snakemake, Nextflow, apptainer exec, ...)
# can run their own shell command in the container. Usage:
#   docker run --rm IMAGE                                   # prints hyphy3 help
#   docker run --rm -v "$PWD":/data IMAGE hyphy3 busted ... # run an analysis
#   docker run --rm IMAGE hyphy3-fel --help                # standalone apps
CMD ["hyphy3", "--help"]
