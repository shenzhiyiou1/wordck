# WeChat Theme Engine

主题目录约定：

- `asset-map.json`: 资源映射与发现结果
- `themes/<name>/theme.json`: 主题配置
- `themes/<name>/assets/<AssetName>@<scale><mode>.png`: 主题资源

当前先维护资源名和配置，后续在 macOS/Theos 环境完成 iOS dylib 编译。
