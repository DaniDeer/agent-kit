# Patched Dockerfile for mcp-servers-git
# Source:  https://github.com/modelcontextprotocol/servers/tree/main/src/git
# Patches: non-root user via fix-docker-perms skill (uses Docker ARG — no hardcoded values)
#
# Build context: mcp-servers/servers-git/src/git/
# Build command (build-mcp-server.sh passes --build-arg automatically):
#   docker build \
#     --build-arg HOST_UID=$(id -u) \
#     --build-arg HOST_GID=$(id -g) \
#     --build-arg HOST_USER=$(id -un) \
#     --file .mcp-dockerfiles/servers-git/Dockerfile \
#     --tag  mcp-servers-git:latest \
#     mcp-servers/servers-git/src/git/

# Use a Python image with uv pre-installed
FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim AS uv

# Install the project into `/app`
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project --no-dev --no-editable

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --no-dev --no-editable

FROM python:3.12-slim-bookworm

RUN apt-get update && apt-get install -y git git-lfs && rm -rf /var/lib/apt/lists/* \
    && git lfs install --system

# Build arguments — passed by build-mcp-server.sh from the host environment.
# Defaults are safe/generic; override with:
#   --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) --build-arg HOST_USER=$(id -un)
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG HOST_USER=user

# Create non-root user matching host user
RUN groupadd -g ${HOST_GID} ${HOST_USER} \
    && useradd -m -u ${HOST_UID} -g ${HOST_USER} ${HOST_USER}

WORKDIR /app

# Keep uv-managed Python at /root/.local (venv symlinks point there); make it world-readable
COPY --from=uv /root/.local /root/.local
RUN chmod 755 /root && chmod -R a+rX /root/.local

COPY --from=uv --chown=${HOST_USER}:${HOST_USER} /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

USER ${HOST_USER}

# when running the container, add --db-path and a bind mount to the host's db file
ENTRYPOINT ["mcp-server-git"]
