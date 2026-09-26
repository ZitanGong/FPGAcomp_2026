# 内部 OSC 按键重映射版验证（2026-09-26）

当前顶层直接使用 Gowin 内部 OSC 和板载 PT8211，不依赖 V13、MS5351 或 FPGA PLL。处理时钟标称 52.5MHz，采样率标称 51.26953125kHz。

消抖后的物理 SW 位通过独立 `key_map` 重新排列：

| 行 | C / Do | D / Re | E / Mi | F / Fa | G / Sol | A / La | B / Si |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | SW5 | SW6 | SW7 | SW1 | SW2 | SW3 | SW4 |
| 2 | SW12 | SW13 | SW14 | SW8 | SW9 | SW10 | SW11 |
| 3 | SW19 | SW20 | SW21 | SW15 | SW16 | SW17 | SW18 |

`tb_map` 逐一激励 SW1～SW21，验证每个物理开关只进入指定声部。完整 13 项 XSim 自检均通过，覆盖扫描位序与 H 位、消抖、多键、重按、ADSR、独立声部、混音、PT8211、备用 I²S、四音频谱和顶层期限。顶层仿真测得按键电平到首个完整非零 PT 字约 3.119291ms。

综合网表包含 21 个独立声部、672 位相位寄存器、84 块 pROM、21 个 DSP、1 个内部 OSC、0 个 PLL。PnR 使用 8829 Logic、4750 Register、84 BSRAM、21 DSP；处理时钟 Fmax 为 79.646MHz，Setup/Hold 违例端点均为 0。

综合提示 `key_map` 层次被优化折叠，这是固定连线映射的正常结果；逐键仿真验证的是优化前 RTL 行为。PnR 仍提示显式 52.5MHz 约束与工具 OSC 预设频率不一致，工程保留 2.5ns setup uncertainty，最终时序无违例。内部 OSC 的实际频率和音高仍需上板测量。

当前位流 `impl/pnr/synth21.fs` 的 SHA256 为 `f6505d48a26a47af02f29f8b2455925100bc54f04755a50f1dfdec09f96446de`。该新键序位流尚未上板；此前用户实测结论属于映射修改前的内部 OSC 版本。
