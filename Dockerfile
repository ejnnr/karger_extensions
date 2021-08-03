# base stage contains just dependencies.
FROM python:3.9.6-slim as dependencies
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    julia \
    # needed for the prepare_datasets.sh script
    imagemagick \
    curl \
    tar \
    unzip \
    gzip \
    && rm -rf /var/lib/apt/lists/*

RUN julia -e 'using Pkg; Pkg.add.(["StatsBase", "HDF5"])'

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/install-poetry.py | python -
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /karger_extensions
# Copy only necessary dependencies to build virtual environment.
# This minimizes how often this layer needs to be rebuilt.
COPY ./poetry.lock pyproject.toml ./
RUN poetry install --no-interaction --no-ansi

COPY ./grabcut.txt ./
COPY ./scripts/prepare_datasets.sh ./scripts/prepare_datasets.sh
COPY ./src/read_usps.py ./src/read_usps.py
RUN poetry run scripts/prepare_datasets.sh

# to make it easier to mount into these directories for development
RUN rm ./src/* ./scripts/*

# full stage contains everything.
FROM dependencies as full

# Delay copying the code until the very end
COPY . /karger_extensions