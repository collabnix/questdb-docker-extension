FROM golang:1.19-alpine AS builder
ENV CGO_ENABLED=0
WORKDIR /backend
COPY vm/go.* .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go mod download
COPY vm/. .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -trimpath -ldflags="-s -w" -o bin/service

FROM --platform=$BUILDPLATFORM node:18.12-alpine3.16 AS client-builder
WORKDIR /ui
# cache packages in layer
COPY ui/package.json /ui/package.json
COPY ui/package-lock.json /ui/package-lock.json
RUN --mount=type=cache,target=/usr/src/app/.npm \
    npm set cache /usr/src/app/.npm && \
    npm ci
# install
COPY ui /ui
RUN npm run build

FROM alpine
LABEL org.opencontainers.image.title="QuestDB" \
    org.opencontainers.image.description="QuestDB Extension for Docker Desktop" \
    org.opencontainers.image.vendor="Ajeet Singh Raina" \
    com.docker.desktop.extension.api.version="0.3.0" \
    com.docker.extension.screenshots="[ \
    {\"url\": \"https://raw.githubusercontent.com/collabnix/questdb-docker-extension/main/questdb.png\", \"alt\": \"Screenshot\"} \
    ]" \
    com.docker.extension.categories="Databases" \
    com.docker.desktop.extension.icon="https://raw.githubusercontent.com/collabnix/questdb-docker-extension/main/questdb.svg" \
    com.docker.extension.detailed-description="QuestDB is a relational column-oriented database designed for time series and event data. It uses SQL with extensions for time series to assist with real-time analytics. With this Docker extension, you can setup QuestDB with a single click." \
    com.docker.extension.publisher-url='[{"title":"GitHub", "url":"https://github.com/collabnix/questdb-docker-extension/"}]' \
    com.docker.extension.additional-urls='[{"title":"GitHub","url":"https://https://github.com/collabnix/questdb-docker-extension/"}]' \
    com.docker.extension.changelog=""
COPY --from=builder /backend/bin/service /
COPY docker-compose.yaml .
COPY metadata.json .
COPY questdb.svg .
COPY --from=client-builder /ui/build ui
CMD /service -socket /run/guest-services/backend.sock
