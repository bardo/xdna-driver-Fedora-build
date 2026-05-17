FROM fedora:44 AS build

RUN dnf -y install @development-tools cmake gcc-c++

RUN git clone --recursive https://github.com/amd/xdna-driver.git /xdna-driver


### Xilinx XRT ###

# Install dependencies
RUN ./xdna-driver/xrt/src/runtime_src/tools/scripts/xrtdeps.sh

# Some dependencies are not installed by xrtdeps.sh, let's make sure we have all we need
RUN dnf -y install \
    boost-devel \
    boost-static \
    glibc-static \
    json-glib-devel \
    libcurl-devel \
    libdrm-devel \
    libstdc++-static \
    libuuid-devel \
    ncurses-devel \
    ocl-icd-devel \
    openssl \
    pybind11-devel \
    python3-pybind11 \
    rapidjson-devel \
    rpmbuild \
    systemtap-sdt-devel

# XRT explicitly checks for CMake 3 which is not available in Fedora, but it builds just fine with CMake 4
RUN cd xdna-driver/xrt/build && sed -i 's/cmake3/cmake4/' build.sh && ./build.sh -npu -opt
RUN cd xdna-driver/xrt/build/Release && make package


### AMD XDNA ###

# Install dependencies
RUN ./xdna-driver/tools/amdxdna_deps.sh

# Make sure that all dependencies are installed
RUN dnf -y install \
    jq \
    wget

# Try to install the kernel headers for the running kernel, if the package is not available get it from Koji
RUN echo "KERNEL_VERSION=$(uname -r | rev |cut -d '.' -f 2- | rev)" >/tmp/kernel_version
RUN echo "KERNEL_ARCH=$(uname -r | rev | cut -d '.' -f 1 | rev)" >>/tmp/kernel_version
RUN . /tmp/kernel_version && dnf -y install kernel-devel-$KERNEL_VERSION kernel-headers-$KERNEL_VERSION \
    || ( \
        dnf -y install koji \
        && . /tmp/kernel_version \
        && koji download-build --arch="$KERNEL_ARCH" "kernel-$KERNEL_VERSION.$KERNEL_ARCH" \
        && dnf -y install kernel-core-$KERNEL_VERSION.$KERNEL_ARCH.rpm kernel-modules-core-$KERNEL_VERSION.$KERNEL_ARCH.rpm kernel-devel-$KERNEL_VERSION.$KERNEL_ARCH.rpm \
    )

# Again replace CMake 3 with CMake 4
RUN cd xdna-driver/build && sed -i 's/cmake3/cmake4/' build.sh && KERNEL_SRC=/usr/src/kernels/$(uname -r)/ ./build.sh -release


### Copy artifacts ###
FROM scratch

COPY --from=build /xdna-driver/build/Release/*.rpm /artifacts/
COPY --from=build /xdna-driver/xrt/build/Release/*.rpm /artifacts/
