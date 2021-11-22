FROM debian:bullseye

RUN apt-get update && \
    apt-get install -y sudo wget python3

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
RUN wget https://download.jetbrains.com/python/pycharm-community-2021.2.3.tar.gz && \
    sudo mkdir /opt/pycharm && \
    sudo tar xzf pycharm-*.tar.gz -C /opt/pycharm --strip-components 1 && \
    sudo rm -rf pycharm-*.tar.gz && \
    sudo chown -R developer:developer /opt/pycharm
RUN sudo apt-get install -y libxrender1 libxtst6 libxi6 libfreetype6 fontconfig

# Run pycharm
CMD sh /opt/pycharm/bin/pycharm.sh

# Command to build the image
#
# docker build -t pycharm .

# Command to run pycharm
# (http://fabiorehm.com/blog/2014/09/11/running-gui-apps-with-docker/)
#
# docker run -ti --rm \
#     -e DISPLAY=$DISPLAY \
#     -v /tmp/.X11-unix:/tmp/.X11-unix \
#     pycharm
