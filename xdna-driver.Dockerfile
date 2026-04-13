FROM fedora:43 AS build

RUN dnf -y install @development-tools

RUN git clone --recursive https://github.com/amd/xdna-driver.git /xdna-driver

RUN ./xdna-driver/xrt/src/runtime_src/tools/scripts/xrtdeps.sh
RUN cd xdna-driver/xrt/build && ./build.sh -npu -opt
RUN cd xdna-driver/xrt/build/Release && make package

RUN dnf -y install jq wget
RUN cd xdna-driver/build && KERNEL_SRC=/usr/src/kernels/$(uname -r)/ ./build.sh -release

FROM scratch

COPY --from=build /xdna-driver/build/Release/*.rpm /artifacts/
COPY --from=build /xdna-driver/xrt/build/Release/*.rpm /artifacts/