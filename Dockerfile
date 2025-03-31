FROM nvcr.io/nvidia/pytorch:20.07-py3

# ROS Melodic
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu bionic main" > /etc/apt/sources.list.d/ros-latest.list' && \
    curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add - && \
    apt update && \
    ln -fs /usr/share/zoneinfo/Asia/Taipei /etc/localtime && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata && \
    apt install -y ros-melodic-ros-base && \
    apt install -y python-rosdep python-rosinstall python-rosinstall-generator python-wstool build-essential && \
    rosdep init && \
    rosdep update

RUN apt install -y ros-melodic-navigation \
    ros-melodic-robot-localization \
    ros-melodic-robot-state-publisher \
    ros-melodic-jsk-recognition-msgs \
    ros-melodic-jsk-rviz-plugins

WORKDIR /root
RUN git clone -b 4.0.3 https://github.com/borglab/gtsam.git
RUN mkdir /root/gtsam/build
WORKDIR /root/gtsam/build
# RUN cmake ..  && make -j$(nproc) install
RUN cmake -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SHARED_LIBS=ON \
          -DGTSAM_USE_QUATERNIONS=ON \
          -DGTSAM_USE_SYSTEM_EIGEN=ON \
          -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF \
          -DCMAKE_INSTALL_PREFIX=/usr/local .. && \
          make -j$(nproc) install

# for melodic, resolve conflicting
RUN mv /usr/include/flann/ext/lz4.h /usr/include/flann/ext/lz4.h.bak
RUN mv /usr/include/flann/ext/lz4hc.h /usr/include/flann/ext/lz4hc.h.bak
RUN ln -s /usr/include/lz4.h /usr/include/flann/ext/lz4.h
RUN ln -s /usr/include/lz4hc.h /usr/include/flann/ext/lz4hc.h

WORKDIR /root
RUN wget https://github.com/Kitware/CMake/releases/download/v3.21.2/cmake-3.21.2.tar.gz
RUN tar xzvf cmake-3.21.2.tar.gz
WORKDIR /root/cmake-3.21.2
RUN ./bootstrap && make -j$(nproc)
ENV CMAKE_BIN_PATH=/root/cmake-3.21.2/bin

COPY Caffe2Targets.cmake /opt/conda/lib/python3.6/site-packages/torch/share/cmake/Caffe2/Caffe2Targets.cmake
COPY . /se-ssd
WORKDIR /se-ssd

# SE-SSD dependencies
# RUN apt-get update && apt-get install -y --no-install-recommends \
# python3-opencv
RUN pip install --upgrade pip setuptools wheel
RUN pip3 install -r requirements.txt && \
    pip3 install typing-extensions==4.1.0 && \
    python3 install.py --cmake_executable=/root/cmake-3.21.2/bin/cmake

WORKDIR /root
RUN mkdir -p /root/catkin_ws/src
WORKDIR /root/catkin_ws/src
RUN git clone https://github.com/nanoshimarobot/LIO-SEGMOT.git
WORKDIR /root/catkin_ws
RUN source /opt/ros/melodic/setup.bash && catkin_make

COPY bashrc /root/.bashrc

# CMD ["bash", "-c", "NUMBAPRO_NVVM=/usr/local/cuda/nvvm/lib64/libnvvm.so NUMBAPRO_LIBDEVICE=/usr/local/cuda/nvvm/libdevice/ python3 ros_main.py --subscribed_topic /lio_segmot/keyframe/cloud_info --verbose --mode lio_segmot"]
