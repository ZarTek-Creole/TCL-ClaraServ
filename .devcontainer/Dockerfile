# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.241.1/containers/debian/.devcontainer/base.Dockerfile

# [Choice] Debian version (use bullseye on local arm64/Apple Silicon): bullseye, buster
ARG VARIANT="buster"
FROM mcr.microsoft.com/vscode/devcontainers/base:0-${VARIANT}

# ** [Optional] Uncomment this section to install additional packages. **
RUN apt-get update                                                  && \
export DEBIAN_FRONTEND=noninteractive                               && \
apt-get -y install --no-install-recommends tcl tcl-dev git tcllib tcl-tls build-essential libssl-dev
RUN git clone https://github.com/eggheads/eggdrop.git /workspaces/eggdrop-src
RUN cd /workspaces/eggdrop-src                                      && \
./configure                                                         && \
make config                                                         && \
make                                                                && \
make install DEST=/workspaces/eggdrop                               && \
rm -rf /workspaces/eggdrop-src
RUN mkdir -p /workspaces/TCL-ClaraServ/                             && \
ln -s /workspaces/TCL-ClaraServ/ /workspaces/eggdrop/scripts/       && \
ln -s /workspaces/eggdrop/eggdrop.conf /workspaces/TCL-ClaraServ/   && \
chmod 0766 /workspaces/eggdrop/eggdrop.conf                         && \
echo "source /workspaces/TCL-ClaraServ/ClaraServ.tcl" >> /workspaces/eggdrop/eggdrop.conf
RUN git clone https://github.com/ZarTek-Creole/TCL_Exec.git /workspaces/TCL_Exec
RUN ln -s /workspaces/TCL_Exec/ /workspaces/eggdrop/scripts/        && \
echo "source /workspaces/TCL_Exec/TCL_Exec.tcl" >> /workspaces/eggdrop/eggdrop.conf