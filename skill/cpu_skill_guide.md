# RISC-V CPU 工程 Skill 技能包

本包从实际 `RISCV_5pipeline.xpr`、RTL、Block Design、验证入口和历史故障记录中提炼，包含 **3 个 Skill**。目标是让陌生开发者能够重做检查并保留证据。分析基线为 2026-11-03，主核为 **IF–ID–EX0–EX1–MEM–WB 六级流水线**，器件 `xc7k325tffg676-2`，Vivado 2026.1。

快速入口：[真实工程分析](project_analysis.md)、[本轮验证记录](evidence/validation.json)、[比赛要求对应](competition_mapping.md)、[可放进设计报告的说明](report_excerpt.md)。

| Skill | 适用场景 | 使用入口 | 失效边界 |
| --- | --- | --- | --- |
| [riscv-verification](riscv-verification/SKILL.md) | ALU、寄存器、前递/暂停/保存、CSR、复位模块测试；写回比对和已有全核周期记录复核 | `run_units.py`、`compare_trace.py`、`recheck_existing.py` | 模块仿真不能证明全核、BRAM 物理时序或板级通过；当前 TB 适配器依赖本项目接口 |
| [vivado-automation](vivado-automation/SKILL.md) | MCP 只读检查、隔离副本仿真/综合/实现、报告提取 | `mcp_inspect.py`、`build.py`、`analyze_reports.py` | R1 构建适配器限定当前 Kintex-7/Windows 工程；通用报告解析与之分离 |
| [riscv-debug](riscv-debug/SKILL.md) | 从 RTL/BD/日志/波形定位六级流水线错误，生成可核对的接口清单 | `inspect_project.py`、提示词模板 | 静态清单不是综合网表；没有波形/日志时只能给待验证假设 |

## 目录与依赖

```text
skill/
  README.md                       总入口、使用与复现
  project_analysis.md              实际架构、脚本关系及证据边界
  competition_mapping.md           指南条款与交付物对应
  report_excerpt.md                设计报告用简要说明
  collaboration_record.md          本轮真实协作与纠错记录摘要
  references/                     本地指南相关节选与来源哈希
  evidence/                       本轮小体积结果、保护清单和原始仿真日志
  scripts/validate_package.py      路径、格式、脚本与负对照检查
  riscv-verification/              SKILL.md、流程、提示词、脚本、实际示例
  vivado-automation/               SKILL.md、流程、资源/时序、脚本
  riscv-debug/                    SKILL.md、架构/冒险排查、提示词、静态检查脚本
  artifacts/                      本机运行产物；Git 忽略，不当作提交源码
```

Python 脚本只用标准库，要求 Python **3.10+**。模块仿真选用 Icarus Verilog（`iverilog`、`vvp` 在 PATH）或 Vivado 2026.1 自带 XSim。本机已验证 Python 3.12、Icarus 和 XSim。使用 `python -B -X utf8` 可避免原工程产生 `__pycache__` 并稳定输出中文。

原工程、原 TB、约束、COE、报告均作为只读输入。所有 `--out` 必须指向**不存在的新目录**，禁止覆盖；失败后保留日志，改用新的目录名重试。不自动清理任何文件，不操作许可证或 FPGA 下载。

## 从项目根目录复现

以下命令在包含 `RISCV_5pipeline.xpr` 的根目录运行；目录有空格时对路径加引号。示例输出名若已存在，请换名。每个脚本都支持 `--help`。

1. 获取源码/BD 接线清单：

```powershell
python -B -X utf8 skill/riscv-debug/scripts/inspect_project.py --project-root . --out skill/artifacts/my_inventory
```

2. 快速执行四类模块测试：

```powershell
python -B -X utf8 skill/riscv-verification/scripts/run_units.py --project-root . --backend iverilog --out skill/artifacts/my_units
```

没有 Icarus 时，使用实际 Vivado 安装目录。本机示例为：

```powershell
python -B -X utf8 skill/riscv-verification/scripts/run_units.py --project-root . --backend xsim --vivado-bin E:/Vivado2026.1/2026.1/Vivado/bin --out skill/artifacts/my_xsim
```

3. 从已有报告提取资源、时钟、WNS/TNS，并绑定源码：

```powershell
python -B -X utf8 skill/vivado-automation/scripts/analyze_reports.py --report-dir repair_records/timing_recheck_20261028/run_20261028_223130 --project-root . --source-manifest repair_records/timing_recheck_20261028/run_20261028_223130/active_inputs_before.json --out skill/artifacts/my_reports
```

成功仅表示报告中的**片内**时序门槛满足。该历史报告还有 35 项输入/71 项输出延迟缺失；添加 `--require-io-delays` 会使当前检查失败。其他器件也可复用解析器，但未识别的格式返回 `INCOMPLETE`，不得补零凑成通过。

4. 重新比对真实历史全核记录（不启动新仿真）：

```powershell
python -B -X utf8 skill/riscv-verification/scripts/recheck_existing.py --project-root . --run-dir repair_records/phase10/rework_R1/runs/isa_s1_d0_20261021_130046_048067_bba90a --out skill/artifacts/my_recheck
```

5. 验证整个包及判定器的负对照：

```powershell
python -B -X utf8 skill/scripts/validate_package.py --out skill/artifacts/my_validation
```

## 完整仿真、综合和实现

先生成计划，检查 `plan.json`、输入清单、工具路径和磁盘空间：

```powershell
python -B -X utf8 skill/vivado-automation/scripts/build.py --project-root . --vivado-bin E:/Vivado2026.1/2026.1/Vivado/bin --stage implement --out skill/artifacts/my_build_plan
```

`--stage simulate` 复用 `phase10_r1_core.py build/run`；`--stage synth` 只综合；`--stage implement` 先综合再布局布线。**只有追加 `--execute` 才会启动工具**，且必须使用另一个新输出目录。Agent 应先说明耗时并取得用户同意。本轮未执行这些重流程，计划检查不计作构建成功。Windows 深层生成路径可能超限，实际重建推荐使用新建短目录，例如 `C:/fpga_skill_runs/cpu_01`。

## 安装为 Codex / AI Agent Skill

比赛提交位置始终为项目的 `skill/`。兼容 Agent 的入口为三个子目录中的 YAML frontmatter `SKILL.md`；不需要安装就能执行 Python 脚本。

若要本地安装，将需要的整个 Skill 子目录复制到 Agent 的技能搜索目录，例如 `~/.codex/skills/riscv-verification/`。各 Skill 的脚本和参考文件均位于本目录内，不依赖兄弟 Skill；安装后执行脚本时显式传入 `--project-root`，指向实际工程。构建与历史复核仍需要完整项目中的原验证目录；通用写回比较器、报告解析器不需要该项目。不要把整个比赛目录复制成一个不含入口的 Skill。

## 迁移到其他题目

可直接复用：严格写回序列比较器、报告缺失判定、来源哈希绑定、MCP 固定查询的组织方式、基于首个分歧周期的提示词。换 CPU 时，应替换 TB 层次路径、ISA/CSR 契约和周期模型；换器件/工程时，应替换构建适配器，重新验证资源表格式。当前项目之外的板卡、CPU 和操作系统尚未实测，不宣称跨板迁移成功。

## 提交到 Gitee

本任务只创建可审查文件，未创建远程仓库或推送。在已有工程仓库内先检查工作树，只暂存 `skill/`，再审查暂存内容：

```powershell
git status --short
git add -- skill
git diff --cached --stat
git diff --cached
git commit -m "Add reusable RISC-V CPU verification and Vivado skills"
```

确认远程地址及分支后再执行 `git push origin <branch>`。本机工程根目录目前没有 `.git`；首次提交请先在准备提交的副本创建仓库并连接自己的 Gitee 项目。`skill/` 不包含完整 CPU 工程，比赛工程包还需提交必要 RTL/IP 初始化数据、仿真/实现报告和真实板级材料。不要用 `git add .` 把工具、缓存、大型重复构建树或个人路径资料一并上传。

提交前需确定整个作品的开源许可证及上游源码/IP 的再分发范围；本包不替用户替换原项目许可证。原工程含空格/中文路径，与本地指南的仓库命名要求尚有差距；本次按约束保留原文件，仅新增英文路径，完整仓库的迁移与发布仍需另行完成。
