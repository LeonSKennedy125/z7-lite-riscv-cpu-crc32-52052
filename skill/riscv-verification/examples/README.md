# 示例来源

`skill_contract_tb.sv` 是本包新增模块契约测试，编译时使用实际工程RTL；没有复制或修改CPU设计。其覆盖范围见上级workflow，不能代替全核回归。

`expected.trace` 原样复制工程 `verification/phase06_hazards_program/expected.trace` 的完整56条写回期望，包含首行计数。它是项目自建 hazard 用例，**不是官方 RISC-V golden**。`hazards_simulation.log` 是对应历史XSim运行的原始日志，包含实际WRITE记录。来源路径、哈希和历史范围见同目录 `provenance.json`。

仅有本Skill目录时，也可从本目录运行：

```powershell
python -B -X utf8 ../scripts/compare_trace.py --expected expected.trace --actual hazards_simulation.log --actual-format wb-log
```

实际56条写回已严格匹配。这是历史捕获的新比对，不是本轮新全核仿真；不能由此宣称未记录的所有副作用正确。

本轮真正执行的模块仿真日志保存在包根的 `evidence/`；历史全核复核另有明确来源、程序/日志/模型哈希和 `fresh_simulation=false`。
