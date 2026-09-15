# WeChatThemeEngine

## 当前状态

- 已分析 `wx.ipa`：微信 8.0.76，arm64，`LC_ENCRYPTION_INFO_64.cryptid = 0`，可直接用于静态分析与注入改造。
- 已从 `Assets.car` 提取 938 个主题相关资源名，保存到 `themes/asset-map.json`。
- 已创建示例主题 `themes/dark-green`。

## 推荐路线

### 1. 越狱 Tweak 路线

使用 Theos + Logos，Hook `UIImage imageNamed:` / asset catalog 查询，按 `theme.json` 返回自定义图片。适合已有越狱设备。

### 2. 非越狱重签路线

1. 编译 `libWeChatThemeEngine.dylib`，架构 arm64。
2. 用 `optool`/`insert_dylib` 插入 `LC_LOAD_DYLIB` 到 `WeChat`。
3. 将 dylib 与 `themes/` 放入 `WeChat.app/Frameworks/` 或 `Resources/`。
4. 重新签名整个 `.app`、所有 Framework、PlugIns。
5. 打包 IPA 并通过 AltStore/SideStore/TrollStore 安装。

## 目录

```text
WeChatThemeEngine/
├── Tweak.xm                  # Logos Hook，Theos 使用
├── ThemeEngine.mm            # 非越狱 dylib 使用
├── themes/asset-map.json     # 主题资源映射
└── themes/dark-green/        # 示例主题
```

## Windows 编译限制

本机没有 iOS SDK / Theos / ldid / optool，无法直接产出可安装 dylib。Windows 端可以先维护主题包与构建脚本，最终在 macOS 或 WSL+iOS SDK 环境执行编译。

## GitHub Actions 自动编译

项目已提供 `.github/workflows/build.yml`。

### 使用方法

1. 在 GitHub 新建一个私有仓库。
2. 推送整个 `WeChatThemeEngine` 目录。
3. 进入 GitHub 仓库的 `Actions` 页面。
4. 选择 `Build WeChat Theme Engine`，点击 `Run workflow`。
5. 构建完成后，在该次运行页面下载 Artifact。

### 产物

- `WeChatThemeEngine-dylib`：非越狱重签注入用 `WeChatThemeEngine.dylib`
- `WeChatThemeEngine-deb`：越狱环境安装用 `.deb`

### 本地部署路径

越狱 Tweak 默认从以下路径加载主题：

```text
/Library/Application Support/WeChatThemeEngine/themes/dark-green/theme.json
```

非越狱注入版默认从以下路径加载主题：

```text
WeChat.app/Frameworks/WeChatThemeEngine/themes/dark-green/theme.json
```
