FROM python:3.10-slim

# Install compilers and SCIP deps.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    libcliquer1 \
    gfortran \
    libgsl25 \
    liblapack3 \
    libopenblas-dev \
    libtbb2

# Add SCIP optimization suite installer into container.
COPY SCIPOptSuite-8.0.0-Linux-debian.deb /opt/pyscipopt/

WORKDIR /opt/pyscipopt/

# Install SCIP optimization suite and remove installer.
RUN dpkg -i SCIPOptSuite-8.0.0-Linux-debian.deb && \
    rm SCIPOptSuite-8.0.0-Linux-debian.deb 

# Create non-root user.
RUN useradd --no-log-init --user-group --create-home user

# Install the SCIP Python API.
COPY requirements.txt /opt/pyscipopt/
RUN pip install --upgrade pip pip-tools && python -m piptools sync

# Switch to new non-root user.
USER user

# Set new non-root user's home directory as working directory.
WORKDIR /home/user

# Assign home folder for sharing host files.
VOLUME /home/user

# Make container behave as executable.
ENTRYPOINT ["python"]

