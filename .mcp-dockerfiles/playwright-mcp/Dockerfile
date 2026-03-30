ARG PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

# ------------------------------
# Base
# ------------------------------
FROM node:22-bookworm-slim AS base

ARG PLAYWRIGHT_BROWSERS_PATH
ENV PLAYWRIGHT_BROWSERS_PATH=${PLAYWRIGHT_BROWSERS_PATH}

WORKDIR /app

RUN --mount=type=cache,target=/root/.npm,sharing=locked,id=npm-cache \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=bind,source=packages/playwright-mcp/package.json,target=packages/playwright-mcp/package.json \
  npm ci --omit=dev && \
  npx -y playwright-core install-deps chromium

# ------------------------------
# Builder
# ------------------------------
FROM base AS builder

RUN --mount=type=cache,target=/root/.npm,sharing=locked,id=npm-cache \
    --mount=type=bind,source=package.json,target=package.json \
    --mount=type=bind,source=package-lock.json,target=package-lock.json \
    --mount=type=bind,source=packages/playwright-mcp/package.json,target=packages/playwright-mcp/package.json \
  npm ci

COPY packages/playwright-mcp/*.json packages/playwright-mcp/*.js packages/playwright-mcp/*.ts .

# ------------------------------
# Browser
# ------------------------------
FROM base AS browser

RUN npx -y playwright-core install --no-shell chromium

# ------------------------------
# Runtime  (patched: host-uid/gid instead of hardcoded 'node')
# ------------------------------
FROM base

ARG PLAYWRIGHT_BROWSERS_PATH
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG HOST_USER=node

ENV NODE_ENV=production
ENV PLAYWRIGHT_MCP_OUTPUT_DIR=/tmp/playwright-output

# Create a user matching the host UID/GID so bind-mounted directories
# and any output files are owned by the correct user on the host.
# The node:22 base image ships with 'node' at UID/GID 1000; skip
# re-creating it if HOST_UID happens to be 1000.
RUN if [ "${HOST_GID}" != "1000" ]; then \
      groupadd -g "${HOST_GID}" "${HOST_USER}" 2>/dev/null || groupmod -g "${HOST_GID}" "${HOST_USER}"; \
    fi && \
    if [ "${HOST_UID}" != "1000" ]; then \
      useradd -u "${HOST_UID}" -g "${HOST_GID}" -m -s /bin/sh "${HOST_USER}" 2>/dev/null || \
      usermod -u "${HOST_UID}" -g "${HOST_GID}" "${HOST_USER}"; \
    fi

# Give the runtime user ownership of the installed node_modules
RUN chown -R "${HOST_UID}:${HOST_GID}" /app

COPY --from=browser --chown=${HOST_UID}:${HOST_GID} ${PLAYWRIGHT_BROWSERS_PATH} ${PLAYWRIGHT_BROWSERS_PATH}
COPY --chown=${HOST_UID}:${HOST_GID} packages/playwright-mcp/cli.js packages/playwright-mcp/package.json ./

USER ${HOST_UID}:${HOST_GID}

ENTRYPOINT ["node", "cli.js", "--headless", "--browser", "chromium", "--no-sandbox"]
