## BASE
FROM alpine:3.20.1@sha256:b89d9c93e9ed3597455c90a0b88a8bbb5cb7188438f70953fede212a0c4394e0 as base

COPY .python-version /
RUN apk add --no-cache python3~="$(cat .python-version)"
ARG POETRY_VERSION="1.8.3-r0"

## BUILDER
FROM base as builder

ENV POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_IN_PROJECT=1 \
  POETRY_VIRTUALENVS_CREATE=1 \
  POETRY_CACHE_DIR=/tmp/poetry_cache

RUN apk add --no-cache poetry="${POETRY_VERSION}"

WORKDIR /app
COPY pyproject.toml poetry.lock ./

RUN --mount=type=cache,target=$POETRY_CACHE_DIR poetry install --only main --no-root


## TESTER
FROM base as tester

ENV VIRTUAL_ENV=/app/.venv \
  PATH="/app/.venv/bin:$PATH" \
  POETRY_NO_INTERACTION=1 \
  POETRY_VIRTUALENVS_IN_PROJECT=1 \
  POETRY_VIRTUALENVS_CREATE=1 \
  POETRY_CACHE_DIR=/tmp/poetry_cache

WORKDIR /app
RUN mkdir /app/rules && \
  mkdir /app/data && \
  mkdir /.cache && \
  mkdir /.semgrep

# Copy source code, packages, and rules
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY semgr8s/ /app/semgr8s
COPY charts/semgr8s/rules/ /app/rules

# Install test dependencies
RUN apk add --no-cache poetry="${POETRY_VERSION}"
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=$POETRY_CACHE_DIR poetry install --only test

CMD ["pytest", "--cov=semgr8s", "--cov-report=xml:tests/coverage.xml", "tests/"]



## SEMGR8S
FROM base

ENV VIRTUAL_ENV=/app/.venv \
  PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Copy source code and packages
COPY --from=builder ${VIRTUAL_ENV} ${VIRTUAL_ENV}
COPY semgr8s/ /app/semgr8s
COPY build/harden.sh /
RUN sh /harden.sh

USER 10001:20001

LABEL org.opencontainers.image.documentation="https://semgr8ns.github.io/semgr8s/"
LABEL org.opencontainers.image.authors="Christoph Hamsen <christoph.hamsen@securesystems.de>"
LABEL org.opencontainers.image.vendor="Secure Systems Engineering"

CMD ["python", "-m", "semgr8s"]
