# https://hub.docker.com/_/alpine
FROM docker.io/alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS alpine-base

FROM docker.io/golang:1.26.3 AS base
WORKDIR /work
COPY go.mod go.sum ./
RUN go mod download
COPY . .

FROM base AS test
RUN --mount=type=cache,target=/root/.cache/go-build \
    go test ./...

FROM base AS test-coverage
RUN --mount=type=cache,target=/root/.cache/go-build \
    go test -coverprofile=/coverage.txt -mod=readonly -covermode=atomic ./...

FROM scratch AS export-test-coverage
COPY --from=test-coverage /coverage.txt /

FROM docker.io/golangci/golangci-lint:v2.12.2 AS golangci-lint
FROM base AS check
COPY --from=golangci-lint /usr/bin/golangci-lint /usr/bin/
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/golangci-lint \
    golangci-lint run ./...

FROM base AS dep-update
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    set -x && \
    go get -u ./... && \
    go mod tidy

FROM scratch AS export-dep-update
COPY --from=dep-update /work/go.mod /work/go.sum /

FROM registry.k8s.io/kustomize/kustomize:v5.8.1 AS kustomize
FROM alpine-base AS build-manifests
ARG TAG
COPY --from=kustomize /app/kustomize /usr/local/bin/
WORKDIR /work
COPY manifests ./manifests
RUN set -x && \
    cd manifests/namespaced && \
    kustomize edit set image ghcr.io/pfnet/sciuro:${TAG} && \
    kustomize build >/stable.yaml
RUN set -x && \
    cd manifests/non-namespaced && \
    kustomize build >/cluster.yaml

FROM scratch AS export-manifests
COPY --from=build-manifests /stable.yaml /cluster.yaml /

FROM base AS build
RUN --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=cache,target=/go/pkg/mod \
    CGO_ENABLED=0 go build -o /sciuro cmd/sciuro/main.go

FROM scratch AS export
COPY --from=build /sciuro /

FROM alpine-base
COPY --from=build /sciuro /
ENTRYPOINT ["/sciuro"]
