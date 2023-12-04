FROM python:3.9-slim AS builder
LABEL stage=builder

RUN apt-get update && apt-get install -y git alien python3 python3-pip
COPY src/ /l4t2rpm/
RUN cd l4t2rpm/ && python3 -m pip install -r requirements.txt && python3 l4t2rpm.py

FROM registry.access.redhat.com/ubi9/ubi

ARG TORCH_INSTALL="https://developer.download.nvidia.cn/compute/redist/jp/v511/pytorch/torch-2.0.0+nv23.05-cp38-cp38-linux_aarch64.whl"

# Install essential packages and download necessary files
RUN dnf update && dnf install -y createrepo gcc openssl-devel bzip2-devel libffi-devel zlib-devel wget make
RUN wget https://www.python.org/ftp/python/3.8.12/Python-3.8.12.tgz

# Unpack Python 3.8
RUN tar -xzf Python-3.8.12.tgz

# Configure and build Python 3.8
RUN cd Python-3.8.12 && ./configure --enable-shared --enable-optimizations && make -j8 && make altinstall

# Install Python 3.8
RUN cd Python-3.8.12 && cp --no-clobber ./libpython3.8.so* /lib64/ && chmod 755 /lib64/libpython3.8.so* && export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib/

# Clean up Python 3.8 install files
RUN rm -rf /Python3-8.12*

# Install pip
RUN python3.8 -m ensurepip

# Create the local rpm repo
RUN mkdir -p /var/repos/nvidia-rpms/
COPY --from=builder /l4t2rpm/l4t2rpm/cache/5.1.2/common/rpms/ /var/repos/nvidia-rpms/
RUN createrepo /var/repos/nvidia-rpms/
COPY ./docker/nvidia-rpm.repo /etc/yum.repos.d/nvidia-rpm.repo

# Do some broken RPM stuff because we have to (we have no python 3.8... Red Hat)
RUN rpm -i --nodeps \
           /var/repos/nvidia-rpms/libnvinfer8-8.5.2-2.aarch64.rpm \
           /var/repos/nvidia-rpms/cuda-compat-11-4-11.4.31478197-2.aarch64.rpm \
           /var/repos/nvidia-rpms/python3-libnvinfer-8.5.2-2.aarch64.rpm

# Enable EPEL
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm

RUN dnf update && dnf install -y \
                      libcudnn8 \
                      libcurand-11-4 \
                      libcusparse-11-4 \
                      libcublas-11-4 \
                      libcufft-11-4 \
                      cuda-cudart-11-4 \
                      cuda-nvtx-11-4 \
                      cuda-nvrtc-11-4 \
                      numactl \
                      openblas

# Link libraries
RUN ln -s /usr/local/cuda-11.4/ /usr/local/cuda && ln -s /usr/local/cuda /usr/lib/cuda
RUN ldconfig

# Install Torch + dependencies
RUN python3.8 -m pip install aiohttp numpy=='1.19.4' scipy=='1.5.3'; export "LD_LIBRARY_PATH=/usr/lib/llvm-8/lib:$LD_LIBRARY_PATH"; python3.8 -m pip install --upgrade protobuf; python3.8 -m pip install --no-cache ${TORCH_INSTALL}

# Clean up packages
RUN yum remove -y createrepo wget make && yum clean all

# Clean up repo files
RUN rm -rf /var/repos/nvidia-rpms/ && rm -rf /etc/yum.repos.d/nvidia-rpm.repo

# Set mandatory environment settings
ENV NVIDIA_VISIBLE_DEVICE="all"
ENV NVIDIA_DRIVER_CAPABILITIES="all"
