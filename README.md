# dae JP3 REALITY / gRPC 实验构建

非官方、实验性 dae 构建。不是 dae 官方 release，不建议作为常规升级包使用。

## 实机实验结果

第一阶段修复已由 OpenWrt 实机确认：JP3 的 `security=reality + type=grpc` 现在实际执行 REALITY/uTLS，原先普通 TLS 路径返回的 `403 text/html` 已消失。当前首个稳定错误前移为：REALITY 握手完成伪装站 TLS 后，临时证书认证未通过，`verified=false`，随后返回 `REALITY: processed invalid connection`。因此 gRPC path 和 VLESS 尚未获得有效 REALITY underlay。

早期独立 `1.8.10 -> 26.3.27` 构建虽未修复 JP3，但当时 gRPC 分支没有调用 REALITY；修改后的版本字节从未进入 JP3 ClientHello。该实验不能排除服务端 `minClientVer`，需要在第一阶段 transport fix 上重新进行有效 A/B。

## JP3 sing-box REALITY ALPN probe build

key-share 单变量实机结果已建立因果：删除 `X25519MLKEM768` 后，JP3 从 `public_pki_fallback / admission_rejected` 稳定推进为 `reality_temporary / reality_hmac_match=true / verified=true`。MLKEM hybrid share 是此前 admission failure 的关键 wire 差异，后续构建固定保留该 filter。

新的首个失败点为 ALPN：ClientHello 提供 `alpn=["h2"]`，REALITY admission 成功后 negotiated ALPN 为空。本轮仅对 JP3 把 offer 对齐 sing-box gRPC：

```text
alpn_offer=["h2","http/1.1"]
alpn_required=["h2"]
```

校验不会放宽：只有 negotiated `h2` 可成功；空值或 `http/1.1` 均继续在 `phase=alpn_negotiation` 失败。版本保持 `1.8.1`，MLKEM filter、X25519、uTLS fork、SNI、认证参数、gRPC 与 VLESS 均不变。

```text
DAE_JP3_REALITY_PROBE_VERSION=1.8.1
```

- workflow：`.github/workflows/build-jp3-reality-singbox-alpn-probe.yml`
- patch：`patches/jp3-reality-singbox-alpn-probe-5.patch`
- release tag：`jp3-reality-singbox-alpn-probe-5`
- binary/artifact：`dae-jp3-reality-singbox-alpn-probe-arm64`

## JP3 sing-box REALITY key-share probe build

`1.8.1`、`1.8.10`、`26.3.27` 实机均稳定进入 `public_pki_fallback`，client version 已排除。成功对照固定为 sing-box `v1.12.25`（commit `73bfb99ebce7923c485435e4faf8571b412065a9`），其依赖 `github.com/metacubex/utls v1.8.4`。

逐调用比较发现首个明确 wire 差异：sing-box 第一次 `BuildHandshakeState()` 后，从 `supported_curves` 和 `key_share` 同时删除 `X25519MLKEM768`，再执行第二次 build；dae 当前保留 1216-byte hybrid share。合成 ClientHello 对比中，双方 AEAD AAD 都与最终自动 remarshal 后的 wire（清零 SessionId）逐字节相等，且均可解密；因此当前没有证据指向 SessionId 后的自动 build 破坏 AAD。主要结构差异仍是 hybrid share，另有 sing-box gRPC ALPN `h2,http/1.1` 与 dae `h2`，后者本轮不改。

新构建仅对 JP3 删除 `X25519MLKEM768`，保留 GREASE、X25519、refraction-networking/utls `v1.8.2`、h2-only ALPN 及其他全部参数。继续使用已确认的控制版本：

```text
DAE_JP3_REALITY_PROBE_VERSION=1.8.1
```

预期结构日志：

```text
singbox_keyshare_filter reference="sing-box-v1.12.25" hybrid_group="X25519MLKEM768" curve_removed=true share_removed=true
```

- workflow：`.github/workflows/build-jp3-reality-singbox-keyshare-probe.yml`
- patch：`patches/jp3-reality-singbox-keyshare-probe-4.patch`
- release tag：`jp3-reality-singbox-keyshare-probe-4`
- binary/artifact：`dae-jp3-reality-singbox-keyshare-probe-arm64`

## JP3 sing-box REALITY version probe build

此历史构建用于补齐 sing-box `1.8.1` 版本控制。实机结果为 `26.3.27`、`1.8.10`、`1.8.1` 全部稳定返回可信 public-PKI fallback，因此 client version 假设已被否定；构建保留用于复现，不再继续增加版本值。

新构建只增加 JP3 `1.8.1` probe；默认仍为 `26.3.27`。使用：

```text
DAE_JP3_REALITY_PROBE_VERSION=1.8.1
```

允许值为 `1.8.1`、`1.8.10` 和 `26.3.27`；其他值报错。除三个 REALITY version bytes 外，ClientHello 构造、fingerprint、SNI、public key、shortId、ALPN、gRPC、VLESS、timeout、retry、DNS、routing、health check、serviceName、path 和无关协议均不变。

- workflow：`.github/workflows/build-jp3-reality-singbox-version-probe.yml`
- patch：`patches/jp3-reality-singbox-version-probe-3.patch`
- release tag：`jp3-reality-singbox-version-probe-3`
- binary/artifact：`dae-jp3-reality-singbox-version-probe-arm64`

## JP3 REALITY admission diagnostic build

新诊断构建保留第一阶段 REALITY + gRPC 修复，并把默认 REALITY client version 改为 `26.3.27`。仅对 JP3，可通过环境变量选择旧版本对照：

```text
DAE_JP3_REALITY_PROBE_VERSION=1.8.10
```

允许值仅为 `1.8.10` 和 `26.3.27`；未设置时使用默认 `26.3.27`。非 JP3 节点忽略 probe override。

目标限定日志增加：attempt ID、实际 peer（底层可见时）、public key 和 shortId 的解码长度、客户端 UTC 时间、认证 key-share 类型及 wire key 一致性、AEAD 类型、最终 ClientHello wire self-check、peer certificate 分类、REALITY admission 结果，以及不会把 `CONNECTING`/`TRANSIENT_FAILURE` 误称为成功的 gRPC 状态。日志不包含认证值、UUID、完整 URI 或 key hash。

运行时 wire self-check 会在发送前按服务端方式对 SessionId ciphertext、nonce 和清零后的 ClientHello AAD 做反向验证；单元测试另用随机合成参数验证 Chrome wire X25519 对应关系和 AEAD round-trip。该检查能发现客户端构造错误，但不能推导服务端 private key、shortId、SNI、版本门槛或时间策略。

- workflow：`.github/workflows/build-jp3-reality-admission-diag.yml`
- patch：`patches/jp3-reality-admission-diag-2.patch`
- release tag：`jp3-reality-admission-diag-2`
- binary/artifact：`dae-jp3-reality-admission-diag-arm64`

除默认 REALITY version 及显式 JP3 probe override 外，timeout、retry、DNS、routing、health check、VLESS header、serviceName、path 和无关协议保持不变。

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

早期 26.3.27 实验没有进入 REALITY，不能用于接受或排除版本门槛。第一阶段 transport fix 已经实机确认；当前边界是 REALITY admission 被拒绝。新 admission diagnostic 的编译、wire self-check 和 ARM64 CI 成功仍不能证明服务端接受认证；需比较默认 26.3.27 与显式 1.8.10 对照日志，并结合相同节点的 Xray/sing-box 控制实验或服务端安全日志判断 key、shortId、SNI、时间、版本和实际 backend。
