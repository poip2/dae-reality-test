# dae REALITY 26.3.27 单变量测试构建

非官方、实验性 dae 构建。不是 dae 官方 release，不建议作为常规升级包使用。

## 锁定基线

- dae: `5a51cc747ef9e17185d438dc54ebf32c681984db`
- outbound: `cc1a217490f9725953dce65f703b0c2f12dd8b2f`
- outbound module version: `v0.0.0-sticky-ip.0.20260401154811-cc1a217490f9`
- target: `linux/arm64`，OpenWrt aarch64

精确 dae commit 的 `go.mod` 直接要求上述 outbound module version；同一文件还带有指向 `github.com/olicesx/outbound` 的上游 `replace`。本构建不采用该替换目标，而把 `github.com/daeuniverse/outbound` 明确替换到本地检出的精确 `cc1a217...` commit。CI 日志会打印两个 checkout HEAD、临时 `go.mod` diff 和最终 `go version -m`。

## 唯一计划中的 outbound 源码变化

文件：`transport/tls/reality.go`

```text
REALITY client version 1.8.10
->
REALITY client version 26.3.27
```

可审计补丁：[`patches/reality-version-26.3.27.patch`](patches/reality-version-26.3.27.patch)

CI 在应用补丁前强制验证 `1 / 8 / 10`，应用后强制验证 `26 / 3 / 27`，并确认补丁仅产生三行删除、三行新增。依赖通过本地 module replacement 接入；不执行 `go get -u` 或 `go mod tidy`。

## 构建与发布

Workflow：`.github/workflows/build-dae-reality-test.yml`

- push 到 `main`：构建并上传 Actions artifact `dae-reality-26.3.27-arm64`
- 手动 `workflow_dispatch`：额外创建或更新指定 tag 的 prerelease
- 默认 release tag：`reality-test-26.3.27`
- release 文件：
  - `dae-reality-26.3.27-arm64`
  - `SHA256SUMS`
  - `reality-version-26.3.27.patch`

构建复用该 dae commit 的官方 ARM64 流程：Go 1.26、Ubuntu 22.04、clang/LLVM 15、submodules、官方 Makefile、真实 eBPF 生成、`CGO_ENABLED=0`、`GOARCH=arm64`。

## 假设边界

补丁有效目前只是待验证假设。构建成功不能证明 REALITY client version 是根因。只有在同一 OpenWrt、同一配置、同一节点和网络下替换测试二进制后，目标节点从 `NOT ALIVE`/不可用变成 `ALIVE`/可用，才会强力支持此兼容性假设。
