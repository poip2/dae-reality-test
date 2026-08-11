# dae JP3 REALITY / gRPC 实验构建

非官方、实验性 dae 构建。不是 dae 官方 release，不建议作为常规升级包使用。

## 实机实验结果

`REALITY client version 1.8.10 -> 26.3.27`：**FAILED TO FIX JP3**。

补丁版 dae 可以正常启动，但 JP3 仍为 `ALIVE --tcp4/6-> NOT ALIVE`。因此 REALITY client version 假设已被实机否定，不再作为当前主要 root cause。

## JP3 REALITY gRPC fix build

diagnostic 实机证据显示：`security=reality + type=grpc` 被解析，但 effective outbound 的 gRPC construction 没有构造 REALITY underlay。grpc-go 改用普通 `crypto/tls`，服务端随后返回 `HTTP 403` 和 `Content-Type: text/html`；该 HTTP 状态再被 grpc-go 映射为 `PermissionDenied`。VLESS response header error 是后续结果，不是首个错误。

修复构建把链路改为：

```text
VLESS -> gRPC /update/Tun -> authenticated REALITY/uTLS (ALPN h2) -> TCP
```

实现同时阻止 grpc-go 在已经完成 REALITY 的连接外再增加第二层 TLS，并隔离 pre-secured gRPC ClientConn cache。REALITY version 保持 `1.8.10`；serviceName、gRPC path、VLESS header、timeout、retry、DNS、routing、health check 和依赖版本不变。

- workflow：`.github/workflows/build-jp3-reality-grpc-fix.yml`
- patch：`patches/jp3-reality-grpc-fix-1.patch`
- release tag：`jp3-reality-grpc-fix-1`
- binary/artifact：`dae-jp3-reality-grpc-fix-arm64`
- expected proof：`handshake_success verified=true alpn="h2"`，随后 `response_header_ok`

该版本在 OpenWrt 实机通过前仍是 prerelease；源码调用链、单元测试和 ARM64 CI 成功不能代替 JP3 正对照。

## JP3 diagnostic build

新构建不尝试修复协议，只增加目标限定诊断日志，用于确定失败阶段：REALITY / gRPC / VLESS。REALITY version 保持原始 `1.8.10`。

源码调用链审计显示：dae 创建 node 后进入 outbound VLESS dialer；VLESS 外层调用 gRPC transport；该 baseline 的 gRPC 分支直接由 grpc-go `credentials.NewTLS` 建立 `crypto/tls` transport，再创建 `/<serviceName>/Tun` stream，最后写入并读取 VLESS header。`tls.NewReality` 只在 V2Ray `tcp` transport 分支构造，gRPC 分支没有构造 Reality dialer。diagnostic build 只记录该事实及后续错误，不改变此行为。

- workflow：`.github/workflows/build-jp3-diagnostic.yml`
- patch：`patches/jp3-diagnostic-1.patch`
- release tag：`jp3-diagnostic-1`
- binary/artifact：`dae-jp3-diagnostic-arm64`
- log prefixes：`[JP3DIAG][REALITY]`、`[JP3DIAG][GRPC]`、`[JP3DIAG][VLESS]`

## 锁定基线

- dae: `5a51cc747ef9e17185d438dc54ebf32c681984db`
- 有效 outbound：`github.com/olicesx/outbound@52c26f8e759e156d2f5ec97d18590febf74ba8bb`
- 有效 outbound module version：`v0.0.0-sticky-ip.0.20260518034804-52c26f8e759e`
- dae `require` 中记录的版本：`v0.0.0-sticky-ip.0.20260401154811-cc1a217490f9`
- target: `linux/arm64`，OpenWrt aarch64

精确 dae commit 的 `go.mod` 虽直接 `require` `daeuniverse/outbound@cc1a217...`，但同一文件存在生效的 `replace`，实际构建源码是 `github.com/olicesx/outbound@52c26f8...`。直接强制使用 `cc1a217...` 会因缺少 dae 调用的两个 transport cache API 而无法编译。为保持相对于真实构建基线的单变量实验，本构建检出精确有效 commit `52c26f8...`，再用本地 module replacement 接入 patched checkout。CI 日志会打印两个 checkout HEAD、临时 `go.mod` diff 和最终 `go version -m`。

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

## 结论边界

26.3.27 实验已失败，不能解释 JP3 问题。diagnostic build 的编译成功也不证明 root cause；需由 OpenWrt 实机 `[JP3DIAG]` 日志确认实际失败位置。
