# Patched Dockerfile for mcp-servers-sequentialthinking
# Source:  https://github.com/modelcontextprotocol/servers/tree/main/src/sequentialthinking
# Patches:
#   1. COPY paths adjusted for subdir build context (src/sequentialthinking/ is the context,
#      not the monorepo root — so "COPY src/sequentialthinking /app" becomes "COPY . /app")
#   2. Root tsconfig.json inlined as a RUN step (it lives outside the subdir build context;
#      the local tsconfig.json extends ../../tsconfig.json which resolves to /tsconfig.json)
#   3. Non-root user via fix-docker-perms skill (uses Docker ARG — no hardcoded values)
#
# Build context: mcp-servers/servers-sequentialthinking/src/sequentialthinking/
# Build command (build-mcp-server.sh passes --build-arg automatically):
#   docker build \
#     --build-arg HOST_UID=$(id -u) \
#     --build-arg HOST_GID=$(id -g) \
#     --build-arg HOST_USER=$(id -un) \
#     --file .mcp-dockerfiles/servers-sequentialthinking/Dockerfile \
#     --tag  mcp-servers-sequentialthinking:latest \
#     mcp-servers/servers-sequentialthinking/src/sequentialthinking/

FROM node:22.12-alpine AS builder

# Inline the monorepo root tsconfig.json (../../tsconfig.json relative to the subdir).
# The local tsconfig.json extends this file at /tsconfig.json inside the container.
# Source: https://github.com/modelcontextprotocol/servers/blob/main/tsconfig.json
RUN printf '{\n  "compilerOptions": {\n    "target": "ES2022",\n    "module": "Node16",\n    "moduleResolution": "Node16",\n    "strict": true,\n    "esModuleInterop": true,\n    "skipLibCheck": true,\n    "forceConsistentCasingInFileNames": true,\n    "resolveJsonModule": true\n  },\n  "include": ["src/**/*"],\n  "exclude": ["node_modules"]\n}\n' > /tsconfig.json

# Build context is the sequentialthinking subdir — use "." instead of "src/sequentialthinking"
COPY . /app

WORKDIR /app

RUN --mount=type=cache,target=/root/.npm npm install

RUN --mount=type=cache,target=/root/.npm-production npm ci --ignore-scripts --omit-dev

FROM node:22-alpine AS release

# Build arguments — passed by build-mcp-server.sh from the host environment.
# Defaults are safe/generic; override with:
#   --build-arg HOST_UID=$(id -u) --build-arg HOST_GID=$(id -g) --build-arg HOST_USER=$(id -un)
ARG HOST_UID=1000
ARG HOST_GID=1000
ARG HOST_USER=user

# Create non-root user matching host user.
# Alpine node images reserve uid/gid 1000 for the built-in 'node' user — remove it
# first so we can create our own user with the host's uid/gid without conflict.
RUN set -eux; \
    (deluser  node 2>/dev/null || true); \
    (delgroup node 2>/dev/null || true); \
    addgroup -g "${HOST_GID}" "${HOST_USER}"; \
    adduser  -D -u "${HOST_UID}" -G "${HOST_USER}" "${HOST_USER}"

COPY --from=builder /app/dist /app/dist
COPY --from=builder /app/package.json /app/package.json
COPY --from=builder /app/package-lock.json /app/package-lock.json

ENV NODE_ENV=production

WORKDIR /app

RUN npm ci --ignore-scripts --omit-dev

USER ${HOST_USER}

ENTRYPOINT ["node", "dist/index.js"]
