# 内部 OSC 最小按键映射版（2026-09-26）

本次撤销了新增的 `key_map` 逻辑。SN74HC165 扫描、H/G→A 位序、逐键消抖、`keys[20:0]`、21 路声部门控、内部 OSC、混音和 PT8211 通路均保持原结构。唯一的演奏映射变化是重新排列 `rom/notes.hex` 中 SW1～SW21 对应的频率字；板载四音测试键的常量同步改为选中相同四个目标音。

| 行 | C / Do | D / Re | E / Mi | F / Fa | G / Sol | A / La | B / Si |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | SW5 | SW6 | SW7 | SW1 | SW2 | SW3 | SW4 |
| 2 | SW12 | SW13 | SW14 | SW8 | SW9 | SW10 | SW11 |
| 3 | SW19 | SW20 | SW21 | SW15 | SW16 | SW17 | SW18 |

相关的映射表、合成核心、I²S/PT 集成、内部 OSC 顶层、四音频谱和量化质量测试均通过。综合与布局布线完成，网表仍为 21 个独立声部、672 位相位寄存器、84 块 ROM 和 21 个 DSP；使用 8836 Logic、4750 Register，Fmax 77.906MHz，Setup/Hold 违例端点均为 0。该结果是代码和数字仿真验证，最小映射位流尚待实物确认。

位流：

- `impl/pnr/synth21_known_good.fs`：用户此前实测有声的原始版本，SHA256 `86896f700d3c43bbaef9db8e6c5da87a4dfdfb84381a0875cbc7188ebf6ef09b`。
- `impl/pnr/synth21.fs`：只按频率表方式修改 SW 音符映射的新版本，SHA256 `ea871312b8a6a03fe3daef28f4b2dfaa7791d4ab4dda28529ea73333dc2f4392`。

建议先下载 `synth21_known_good.fs` 确认声音恢复，再下载 `synth21.fs` 检查三行音阶。这样可以把音频通路问题和映射问题分开判断。
