# Tang Mega NEO 138K 实时合成器

当前工程已回退到用户实测可正常发声的内部 OSC 版本。顶层为 `top`，仅使用板载 PT8211；V13、MS5351、FPGA PLL 和标准 I²S 均不参与当前输出。

处理时钟由 Gowin `OSC` 原语产生，`FREQ_DIV=4`，标称 52.5MHz。PT8211 每 1024 个处理时钟发送一帧，标称采样率约 51.2695kHz。21 个音符频率字按该标称采样率计算；实际音高会随内部 OSC 偏差变化，因此本版用于稳定回退和功能调试，不能作为精确 48kHz 验收版本。

工程结构保持为三片 SN74HC165、21 键独立消抖、21 个独立相位/正弦 ROM/ADSR/DSP 声部、流水线混音和 PT8211 右对齐发送。扫描、消抖和按键状态位保持原样，只在 `notes.hex` 中调整各 SW 对应的频率。三行 Do～Si 分别对应 SW5/6/7/1/2/3/4、SW12/13/14/8/9/10/11、SW19/20/21/15/16/17/18。

最小映射改动位流为 [synth21.fs](impl/pnr/synth21.fs)，SHA256：`ea871312b8a6a03fe3daef28f4b2dfaa7791d4ab4dda28529ea73333dc2f4392`。已实测正常的原始回退位流另存为 [synth21_known_good.fs](impl/pnr/synth21_known_good.fs)，SHA256：`86896f700d3c43bbaef9db8e6c5da87a4dfdfb84381a0875cbc7188ebf6ef09b`。先用回退位流确认音频通路，再测试最小映射版。

若使用 Gowin GUI，关闭已打开的旧工程会话，再重新打开 `fpga_project1.gprj`，避免旧会话覆盖当前文件列表。

具体接线和下载步骤见 [bringup.md](docs/bringup.md)，实现结构见 [design.md](docs/design.md)。
