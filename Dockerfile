
# Create image
FROM debian:bullseye

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Update apt cache and install some OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        sudo python3 git wget 

# Create a new user, so the container can run as non-root
# OBS: the UID and GID must be the same as the user that own the
# input and the output volumes, so there isn't perms problems!!
ARG USER_UID="1000"
ARG USER_GID="1000"
RUN groupadd --gid $USER_GID developer
RUN useradd --uid $USER_UID --gid $USER_GID --comment "Default User Account" --create-home developer

# Change users passwords
RUN echo "root:root" | chpasswd && \
    echo "developer:developer" | chpasswd

# Add new user to sudoers
RUN usermod -aG sudo developer

# To allow sudo without password
RUN echo "developer ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/developer && \
    chmod 0440 /etc/sudoers.d/developer

# Change user
USER developer
ENV HOME /home/developer

# Change folder
WORKDIR $HOME

# Install pycharm
RUN wget https://download.jetbrains.com/python/pycharm-community-2022.1.3.tar.gz && \
    sudo mkdir /opt/pycharm && \
    sudo tar xzf pycharm-*.tar.gz -C /opt/pycharm --strip-components 1 && \
    sudo rm -rf pycharm-*.tar.gz && \
    sudo chown -R developer:developer /opt/pycharm
RUN apt-get -y -qq --no-install-recommends install \
        # Without this packages, PyCharm don't start
        libxrender1 libxtst6 libxi6 libfreetype6 fontconfig \
        # Without this packages, PyCharm start, but reports that they are missing
        libatk1.0-0 libatk-bridge2.0-0 libdrm-dev libxkbcommon-dev libdbus-1-3 \
        libxcomposite1 libxdamage1 libxfixes3 libxrandr-dev libgbm1 libasound2 \
        libcups2 libatspi2.0-0 libxshmfence1 \
        # Without this packages, PyCharm start, but shows errors when running
        procps

# Run pycharm
CMD sh /opt/pycharm/bin/pycharm.sh

# Commands to build the image
#
# 1- docker volume create pycharm-home
#
# 2- export DOCKER_BUILDKIT=1
#
# 3- docker build --force-rm \
#        --tag pycharm:latest \
#        --build-arg USER_UID=$(stat -c "%u" .) \
#        --build-arg USER_GID=$(stat -c "%g" .) \
#        --file Dockerfile .

# Command to run pycharm
# (http://fabiorehm.com/blog/2014/09/11/running-gui-apps-with-docker/)
#
# docker run -ti --rm \
#     --name pycharm \
#     --env DISPLAY=$DISPLAY \
#     --volume /tmp/.X11-unix:/tmp/.X11-unix \
#     --volume pycharm-home:/home/developer \
#     pycharm:latest

