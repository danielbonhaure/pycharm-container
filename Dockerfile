
##########################
## Set GLOBAL arguments ##
##########################

# Set python version
ARG PYTHON_VERSION=3.12

# Set image variant
ARG IMG_VARIANT="-slim"

# Set user name and id
ARG USR_NAME="pycharm"
ARG USER_UID="1000"

# Set group name and id
ARG GRP_NAME="pycharm"
ARG USER_GID="1000"

# Set users passwords
ARG ROOT_PWD="root"
ARG USER_PWD=${USR_NAME}

# Set PyCharm version
ARG PYCHARM_VERSION="2024.3.3"



######################################
## Stage 1: Install Python packages ##
######################################

# Create image
FROM python:${PYTHON_VERSION}${IMG_VARIANT} AS py_builder

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

# Upgrade pip and install dependencies
RUN python3 -m pip install --upgrade pip
# Copy dependencies from build context
COPY requirements.txt requirements.txt
# Install Python dependencies (ver: https://stackoverflow.com/a/17311033/5076110)
RUN export CPLUS_INCLUDE_PATH=/usr/include/gdal && export C_INCLUDE_PATH=/usr/include/gdal && \
    python3 -m pip wheel --no-cache-dir --no-deps --wheel-dir /usr/src/app/wheels -r requirements.txt



###############################################
## Stage 2: Copy Python installation folders ##
###############################################

# Create image
FROM python:${PYTHON_VERSION}${IMG_VARIANT} AS py_core

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

# Install python dependencies from py_builder
COPY --from=py_builder /usr/src/app/wheels /wheels
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache /wheels/* && \
    rm -rf /wheels



#############################################
## Stage 3: Install management OS packages ##
#############################################

# Create image
FROM py_core AS py_final

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # install Tini (https://github.com/krallin/tini#using-tini)
        tini \
        # to see process with pid 1
        htop procps \
        # to allow edit files
        vim \
        # to show progress through pipelines
        pv \
        # to clone Git projects
        git \
        # to download files
        curl wget && \
    rm -rf /var/lib/apt/lists/*

# Add Tini (https://github.com/krallin/tini#using-tini)
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]



###################################
## Stage 4: Create non-root user ##
###################################

# Create image
FROM py_final AS py_final_nonroot

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Renew ARGs
ARG USR_NAME
ARG USER_UID
ARG GRP_NAME
ARG USER_GID
ARG ROOT_PWD
ARG USER_PWD

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        # to run sudo
        sudo && \
    rm -rf /var/lib/apt/lists/*

# Modify root password
RUN echo "root:${ROOT_PWD}" | chpasswd

# Create a non-root user, so the container can run as non-root
# OBS: the UID and GID must be the same as the user that own the
# input and the output volumes, so there isn't perms problems!!
# Se recomienda crear usuarios en el contendor de esta manera,
# ver: https://nickjanetakis.com/blog/running-docker-containers-as-a-non-root-user-with-a-custom-uid-and-gid
# Se agregar --no-log-init para prevenir un problema de seguridad,
# ver: https://jtreminio.com/blog/running-docker-containers-as-current-host-user/
RUN groupadd --gid ${USER_GID} ${GRP_NAME}
RUN useradd --no-log-init --uid ${USER_UID} --gid ${USER_GID} --shell /bin/bash \
    --comment "Non-root User Account" --create-home ${USR_NAME}

# Modify the password of non-root user
RUN echo "${USR_NAME}:${USER_PWD}" | chpasswd

# Add non-root user to sudoers and to adm group
# The adm group was added to allow non-root user to see logs
RUN usermod -aG sudo ${USR_NAME} && \
    usermod -aG adm ${USR_NAME}



########################################
## Stage 5: Install and setup PyCharm ##
########################################

# Create image
FROM py_final_nonroot AS pycharm_final

# Set environment variables
ARG DEBIAN_FRONTEND=noninteractive

# Set python environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Renew ARGs
ARG USR_NAME
ARG GRP_NAME

# Renew ARGs
ARG PYTHON_VERSION
ARG PYCHARM_VERSION

# Install OS packages
RUN apt-get -y -qq update && \
    apt-get -y -qq upgrade && \
    apt-get -y -qq --no-install-recommends install \
        build-essential

# Download PyCharm IDE
RUN wget https://download.jetbrains.com/python/pycharm-community-${PYCHARM_VERSION}.tar.gz -P /tmp/

# Install packages required to run PyCharm IDE
RUN count=$(ls /tmp/pycharm-*.tar.gz | wc -l) && [ ${count} = 1 ] \
    && apt-get -y -qq --no-install-recommends install \
        # Without this packages, PyCharm don't start
        libxrender1 libxtst6 libxi6 libfreetype6 fontconfig \
        # Without this packages, PyCharm start, but reports that they are missing
        libatk1.0-0 libatk-bridge2.0-0 libdrm-dev libxkbcommon-dev libdbus-1-3 \
        libxcomposite1 libxdamage1 libxfixes3 libxrandr-dev libgbm1 libasound2 \
        libcups2 libatspi2.0-0 libxshmfence1 \
        # Without this packages, PyCharm start, but shows errors when running
        procps libsecret-1-0 gnome-keyring libxss1 libxext6 firefox-esr dbus-x11 \
        libcanberra-gtk-module libcanberra-gtk3-module \
        #libnss3 libxext-dev libnspr4 \
    || :  # para entender porque :, ver https://stackoverflow.com/a/49348392/5076110

# Install PyCharm IDE
RUN count=$(ls /tmp/pycharm-*.tar.gz | wc -l) && [ ${count} = 1 ] \
    && mkdir /opt/pycharm \
    && tar xzf /tmp/pycharm-*.tar.gz -C /opt/pycharm --strip-components 1 \
    && chown -R ${USR_NAME}:${GRP_NAME} /opt/pycharm \
    || :  # para entender porque :, ver https://stackoverflow.com/a/49348392/5076110

# PyCharm espera que los paquetes python estén en dist-packages, pero están en site-packages.
# Esto es así porque python no se instaló usando apt o apt-get, y cuando esto ocurre, la carpeta
# en la que se instalan los paquetes es site-packages y no dist-packages.
RUN mkdir -p /usr/local/lib/python${PYTHON_VERSION}/dist-packages \
    && ln -s /usr/local/lib/python${PYTHON_VERSION}/site-packages/* \
             /usr/local/lib/python${PYTHON_VERSION}/dist-packages/

# Change to non-root user
USER ${USR_NAME}

# Create PyCharmProjects folder
RUN mkdir -p /home/${USR_NAME}/PycharmProjects

# Set work directory
WORKDIR /home/${USR_NAME}

# Run pycharm under Tini (https://github.com/krallin/tini#using-tini)
CMD ["/opt/pycharm/bin/pycharm", "-Dide.browser.jcef.enabled=true"]
# or docker run your-image /your/program ...



#####################################################
## Usage: Commands to Build and Run this container ##
#####################################################


# BUILD PYCHARM IMAGE
# 
# docker build --force-rm \
# --target pycharm_final \
# --tag pycharm-ide:latest \
# --build-arg USER_UID=$(stat -c "%u" .) \
# --build-arg USER_GID=$(stat -c "%g" .) \
# --file Dockerfile .


# OBS: when using wayland, run "xhost +" first and "xhost -" after 
#      for more info see: https://unix.stackexchange.com/q/593411
#      or "xhost +SI:localuser:$(id -un)" instead
#      for more info see: https://unix.stackexchange.com/a/359244
# xhost +SI:localuser:"$(id -un)"


# RUN PYCHARM CONTAINER
#
# docker run --tty --interactive \
# --name PyCharmIDE \
# --env DISPLAY="${DISPLAY}" \
# --mount type=bind,source=/tmp/.X11-unix,target=/tmp/.X11-unix \
# --mount type=bind,source="$(pwd)"/PycharmProjects,target=/home/pycharm/PycharmProjects \
# --workdir /home/pycharm/PycharmProjects \
# --detach --rm pycharm-ide:latest
