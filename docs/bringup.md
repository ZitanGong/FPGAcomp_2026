# 内部 OSC / PT8211 上板步骤

当前版本不需要外部时钟、串口命令或 MS5351 配置。直接下载 `impl/pnr/synth21.fs`，然后测试板载 S2/USER_BUTTON1 和自制键盘。

| 信号 | FPGA 球位 / 位置 | 说明 |
|---|---|---|
| rst_n | AA13 / S4 | 低有效复位 |
| test_n | AB13 / S2 | 板载四音测试键 |
| shld | AA21 / J8-8 | SN74HC165 SH/LD# |
| key_clk | AB20 / J8-6 | SN74HC165 CLK |
| key_in[0] | AA19 / J8-5 | OUT1 |
| key_in[1] | D19 / J13-37 | OUT2 |
| key_in[2] | D16 / J13-27 | OUT3 |
| hp_bclk | Y17 | PT8211 BCK |
| hp_ws | AB17 | PT8211 WS |
| hp_sd | AA16 | PT8211 DIN |
| pa_n | AB16 | 耳放使能，运行时为低 |
| dbg_key | R18 / J9-5 | 任意消抖按键按下为高 |
| dbg_err | T18 / J9-6 | 正常为低，键盘帧或音频链路故障后为高 |

键盘使用 3.3V 并与 FPGA 共地。三片 SN74HC165 的 H 固定接高，CLK INH 接地，OUT 使用 QH（9 脚）。

三行从左到右的 Do～Si 映射为：

| 行 | Do | Re | Mi | Fa | Sol | La | Si |
|---|---:|---:|---:|---:|---:|---:|---:|
| 1 | SW5 | SW6 | SW7 | SW1 | SW2 | SW3 | SW4 |
| 2 | SW12 | SW13 | SW14 | SW8 | SW9 | SW10 | SW11 |
| 3 | SW19 | SW20 | SW21 | SW15 | SW16 | SW17 | SW18 |

内部 OSC 标称 52.5MHz，因此 WS 标称约 51.2695kHz，BCK 标称约 1.6406MHz。内部振荡器存在器件和温度偏差，实测值可能变化。本版不用于精确 48kHz 和音准验收。
