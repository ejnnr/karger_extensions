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

RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
RUN poetry config virtualenvs.create false

WORKDIR /karger_extensions
# Copy only necessary dependencies to build virtual environment.
# This minimizes how often this layer needs to be rebuilt.
COPY ./poetry.lock ./poetry.lock
RUN poetry install --no-interaction --no-ansi && yes | poetry cache clear . --all
# to make it easier to mount into this directory
RUN rm poetry.lock

# full stage contains everything.
FROM dependencies as full

# Delay copying the code until the very end
COPY . /reward_preprocessing