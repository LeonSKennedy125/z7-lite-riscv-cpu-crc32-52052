# 运行控制台与结果查看

从仓库根运行，下载文件取自 `board/runtime/`。

```powershell
# 相同板卡上执行三轮：会下载并复位，需已连接硬件。
python -B -X utf8 report/demo/demo_console.py --demo --runs 3

# 读取仓库已保存的完整三轮记录：无需硬件。
python -B -X utf8 report/demo/demo_console.py --show report/demo/runs_20261104_120839

# 离线核对最新 runs_* 目录、执行校验器负对照。
python -B -X utf8 report/demo/show_evidence.py run
python -B -X utf8 report/demo/show_evidence.py verify
python -B -X utf8 report/demo/show_evidence.py test
```

交互模式使用 `python -B -X utf8 report/demo/demo_console.py`，输入 `DEMO 3`、`RESTART` 或 `QUIT`。`--offline` 回放正式 S05 已存样本，`--show` 显示选定的已存三轮结果。

`show_evidence.py dis/map/rom` 打开本机 `run.py firmware` 生成的反汇编、链接 MAP 和 ROM 文件，需要先完成固件构建。未安装 VS Code 时使用记事本展示。

推荐的一次性完整离线核对为 `python -B -X utf8 scripts/verify_saved.py`。本目录只包含运行/查看源码与选定原始数据，不分发作品演示视频。
