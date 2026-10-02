# omega-apis

Protobuf/gRPC schema registry for Omega APIs. GitHub is the schema registry
(protos + git history + tags) and GitHub Actions is the SDK factory — no Buf
Schema Registry (BSR) involved.

## Layout

```
protos/           Proto source of truth (omega.v1 package, etc.)
sdk/go/           Generated Go SDK (own go.mod)
sdk/python/       Generated Python SDK (own pyproject.toml)
buf.yaml          Lint + breaking-change rules
buf.gen.yaml      Go codegen plugins (protoc-gen-go, protoc-gen-go-grpc)
.github/workflows/
  proto-ci.yml       PR checks: lint, breaking-change detection, stale-SDK check
  proto-release.yml  On push to main: regenerate SDKs, commit, tag a release
```

## Prerequisites

- [buf CLI](https://buf.build/docs/installation) (`brew install bufbuild/buf/buf`)
- Go 1.25+ with `protoc-gen-go` and `protoc-gen-go-grpc` on `PATH`
- Python 3.9+ with `grpcio-tools` and `mypy-protobuf` installed

```
make tools
```

## Common tasks

| Command              | What it does                                                |
|----------------------|--------------------------------------------------------------|
| `make lint`          | Run `buf lint` against `protos/`                              |
| `make breaking`      | Check for breaking changes against `main`                     |
| `make generate`      | Regenerate both the Go and Python SDKs                        |
| `make generate-go`   | Regenerate only `sdk/go`                                      |
| `make generate-python` | Regenerate only `sdk/python`                                |
| `make build-go`      | Build the generated Go module                                 |
| `make check`         | lint + breaking + generate, then fail if the diff isn't clean |
| `make clean`         | Remove generated SDK output                                   |

Why Python generation doesn't go through `buf generate`: buf's native Python
output isn't mature enough yet for this project's needs, so Python codegen
shells out to `grpc_tools.protoc` directly (see `generate-python` in the
Makefile).

## Workflow

1. Edit or add `.proto` files under `protos/`, following the
   `<package>/<version>/*.proto` directory convention required by
   `buf lint`'s `STANDARD` ruleset (e.g. `omega.v1` lives in
   `protos/omega/v1/`).
2. Run `make check` locally and commit the regenerated SDK output alongside
   your proto changes.
3. Open a PR. `proto-ci.yml` runs `buf lint`, `buf breaking` against `main`,
   and verifies the committed SDKs match what codegen produces.
4. On merge to `main`, `proto-release.yml` regenerates the SDKs, commits any
   remaining diff back to `main`, and pushes an auto-incremented `vX.Y.Z` tag.

## Versioning

Releases are tagged `vMAJOR.MINOR.PATCH`, auto-incrementing the patch version
on every proto change merged to `main`. `buf breaking` blocks PRs that would
break wire compatibility before they can merge, so a breaking change requires
deliberately removing/renaming instead of bumping major/minor automatically.

Each release also gets a second tag, `sdk/go/vMAJOR.MINOR.PATCH`, pointing at
the same commit. `sdk/go` is a nested Go module (it has its own `go.mod`
under `github.com/nishantapatil3/omega-apis/sdk/go`), and Go's module
system only resolves tagged releases for a nested module from tags of the
form `<module-subdir>/vX.Y.Z` — a bare `vX.Y.Z` tag at the repo root is
invisible to it.

## Installing the SDKs

The repo is **currently private**; it's expected to go public later. Install
commands differ slightly until then.

### While the repo is private

**Go** — needs git to authenticate and `GOPRIVATE` so the module isn't routed
through the public module proxy/sumdb (which can't see a private repo):

```sh
export GOPRIVATE=github.com/nishantapatil3/*
# pick one auth method:
git config --global url."ssh://git@github.com/".insteadOf "https://github.com/"
# or: git config --global url."https://<PAT>@github.com/".insteadOf "https://github.com/"

go get github.com/nishantapatil3/omega-apis/sdk/go@v0.0.1
```

`sdk/go/go.sum` is committed, which `go get` needs to verify checksums once
`GOPRIVATE` bypasses the public sumdb.

**Python** — `pip install git+https://...` needs credentials for a private
repo; use SSH or a token-embedded URL:

```sh
pip install "git+ssh://git@github.com/nishantapatil3/omega-apis.git@v0.0.1#subdirectory=sdk/python"
# or: pip install "git+https://<PAT>@github.com/nishantapatil3/omega-apis.git@v0.0.1#subdirectory=sdk/python"
```

### Once the repo is public

Drop the `GOPRIVATE`/git-rewrite and SSH/token requirements — both commands
work as-is:

```sh
go get github.com/nishantapatil3/omega-apis/sdk/go@v0.0.1

pip install "git+https://github.com/nishantapatil3/omega-apis.git@v0.0.1#subdirectory=sdk/python"
```

In both cases, swap `@v0.0.1` for any tagged release (or drop the version to
get the default branch).
