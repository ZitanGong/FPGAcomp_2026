# MPR121 八段触摸与 16 个 LED

2026-10-03：本版改为每段电极控制相邻两盏灯，取消原先的加权位置、16 区插值和位置滞回。触摸仅控制 LED；原有 OSC、21 键、音色、音量和 PT8211 音频继续运行，标准 I²S 未启用。

## 通道与灯的关系

| 物理段 | 默认 MPR121 通道 | `touch` 位 | `filt` / `base` 切片 | 点亮的灯 | `leds` |
|---|---|---|---|---|---|
| P1 | ELE0 | 0 | [9:0] | LED1、2 | 0003 |
| P2 | ELE1 | 1 | [19:10] | LED3、4 | 000C |
| P3 | ELE2 | 2 | [29:20] | LED5、6 | 0030 |
| P4 | ELE3 | 3 | [39:30] | LED7、8 | 00C0 |
| P5 | ELE4 | 4 | [49:40] | LED9、10 | 0300 |
| P6 | ELE5 | 5 | [59:50] | LED11、12 | 0C00 |
| P7 | ELE6 | 6 | [69:60] | LED13、14 | 3000 |
| P8 | ELE7 | 7 | [79:70] | LED15、16 | C000 |

表中十六进制值是单段触摸时的值。多段同时触摸时点亮各自灯对；无触摸时为 `0000`。相邻电极同时感应到手指时可能亮四盏灯，这是逐段映射的结果。

旧版依据最初接线说明取 ELE1～ELE8。用户随后确认：触摸 P2 时，第一组 `filt[9:0]`（旧版 ELE1）变化最大。因此本版推断实际接线更可能是 ELE0～ELE7，顶层 `TOUCH_FIRST=0`。这不是已经完成的硬件连通性测量：烧录后须分别触摸 P1 和 P8，确认首末组响应。如果实测接线确实为 ELE1～ELE8，设 `TOUCH_FIRST=1` 重新编译；支持的起始通道是 0 或 1。

`filt` 是 10 位滤波测量值，`base` 已按基线寄存器左移两位，二者单位一致。触摸通常让 `filt` 下降；判断强弱应比较每一路自己的 `base-filt`，不能直接比较不同电极的绝对 `filt`。原始测量值仅用于调试，灯由 MPR121 的触摸位控制。

## 松手与响应

- 每次有效读取都覆盖八路触摸状态。`touch_map` 在下一个处理时钟更新全部 16 位灯状态，包括全零，没有位置保持功能。
- 74HC595 在数据变化后立即开始发送；正在发送的一帧会完整结束，接着发最新状态。松手也发送 16 位全零并产生 STCP 脉冲，不能只把 DATA 拉低。
- 收不到新采样超过 20 ms，或模块不再 ready，灯状态清零。正常长按且采样持续时不会自动熄灭。
- MPR121 阈值默认为触摸 12、释放 6；`0x5B=0x01` 保留触摸消抖，移除额外释放消抖。`0x5C=0x10`、`0x5D=0x20`，ESI=1 ms、SFI=4，传感器滤波仍需时间。
- 默认 `TOUCH_HZ=350000`，在标称 52.5 MHz 下实际 SCL 约 345 kHz，低电平约 1.45 μs；轮询间隔约 2 ms，IRQ 低可提前读取。每帧读取 39 字节并检查 ECR。外部上拉、线长及实际 OSC 频率仍需实测。
- 595 移位约 100 kHz，灯状态变化后至锁存通常不超过两次完整传输，约 0.35 ms；这是 RTL 传输预算，不是手指到灯的实测总延迟。

旧版代码也会在收到 `touch=0` 后清灯，尚无证据证明原来的不灭灯一定是 FPGA 锁存错误。若新程序松手后 `touch` 仍非零，应检查传感器基线和阈值；若 `touch=0` 而灯仍亮，应沿 FPGA 灯状态、串行输出、595 锁存逐级定位。

## 文件与参数

| 文件 | 作用 |
|---|---|
| `src/touch/i2c_reg.v` | 开漏 I²C 主机、ACK 检查、重复起始、时钟等待、超时和总线清理 |
| `src/touch/mpr121.v` | 初始化、起始通道选择、周期读取、异常检测和重试 |
| `src/touch/touch_map.v` | 八路触摸位映射到八对 LED、反向及采样超时清零 |
| `src/touch/led595.v` | 高位先移入 16 位，完整移位后锁存，变化时立即刷新 |
| `src/touch/touch_led.v` | 触摸通路集成 |
| `src/top.v` | 顶层参数和端口，与音频共用原处理时钟 |
| `src/touch_dbg.rao` | 保留现有 GAO 探针和 valid 触发设置 |
| `constraints/audio.sdc` | 处理时钟与接口约束，以及 GAO 的 20 MHz TCK 异步时钟组 |

顶层参数：`TOUCH_FIRST=0`、`TOUCH_TH=12`、`RELEASE_TH=6`、`LED_REV=0`、`TOUCH_HZ=350000`。`LED_REV=1` 反转八对灯的方向，不改变电极读取顺序。若提高总线速率后出现 fault，可先改为 `TOUCH_HZ=100000` 核对接线和外部上拉；此时读帧耗时变长，不再达到 2 ms 轮询节拍。

`TOUCH_FIRST=0` 时 ECR=0x88，只启用 ELE0～ELE7；设为 1 时 ECR=0x89，ELE0 的阈值设为 255/254，输出只取 ELE1～ELE8。NACK、总线超时、ECR 错误、过流都会清灯，等待 100 ms 后重新初始化。

## 接线（本次未改动）

| 顶层变量 | 外设端 | FPGA / 底板接口 |
|---|---|---|
| `touch_scl` | MPR121 SCL | E14 / J13-1 |
| `touch_sda` | MPR121 SDA | C15 / J13-3 |
| `touch_irq_n` | MPR121 IRQ | B13 / J13-5 |
| `led_data` | H4-1 DATA | C20 / J13-35 |
| `led_clk` | H4-2 SRCLK | D19 / J13-37 |
| `led_lat` | H4-3 STCP | C19 / J13-39 |
| 无 | H4-6、MPR121 GND | J13-12 或 PMOD GND |
| 无 | MPR121 ADD | GND，地址 0x5A |
| 无 | 外设 VCC | 3.3 V，例如 J8/J9-1、2 |

J13-2 是信号 E13，不是地；J13-11 是 5 V，不可当 3.3 V。信号映射此前按 31005 原理图核对。`dbg_frame` 已在此前修复中移至 E19/J13-38，避免和 `led_clk` 共用 D19。

SCL、SDA、IRQ 需要上拉到 3.3 V，确认模块现有电阻；不能仅依靠 FPGA 弱上拉。两板共地，595 板 DATA/CLK/STCP 的 2.2 kΩ 上拉也接 3.3 V。`dbg_err`（T18）为音频错误与触摸错误的逻辑或。

595 的 /OE 接地，硬件上电到首次锁存前的灯状态不由 RTL 保证。程序启动即发送全零。

## 编译与检查

1. 打开 `fpga_project1.gprj`，从综合开始重新生成位流；或执行 `gw_sh build.tcl`。GUI 和 CLI 均包含 `src/touch_dbg.rao`，不能沿用旧的中间综合结果。
2. 本工程启用 GAO 时输出是 `impl/pnr/ao_0.fs`，下载这个新文件，GAO 加载 `src/touch_dbg.rao`。目录里的 `synth21.fs` 是此前留下的旧位流，不是本次输出。TCK 设置不超过 20 MHz；若以后禁用 GAO，同时移除 `constraints/audio.sdc` 中两条 TCK 约束。
3. 上电约 150 ms 内不要触摸，等待基线初始化。先验证 P1、P8，再依次验证八段及松手。
4. GAO 保留 `u_touch/valid=1` 触发，捕获八路 touch、filt、base、leds、ready、fault。展开 filt/base，按表中每 10 位一组看无符号十进制值；不要把整个 80 位总线当一个测量值。
5. P1 单独触摸预期 `touch=01, leds=0003`；P8 为 `80, C000`。松手后应 `touch=00, leds=0000`。valid 触发点后再看两三个 clk，避免把映射更新前的旧 leds 当作故障。
6. 若松手后 touch 持续非零，记录对应 `base-filt`：大于释放阈值时传感器仍判定触摸。检查电极残留接触、潮湿、共地、邻线耦合；先在不触摸时重新上电建立基线，再按数据调整阈值，保持 `RELEASE_TH < TOUCH_TH`。
7. 若 touch 与 leds 已归零而实灯未灭，测 DATA/CLK/STCP：应完整移入 16 个零后出现 STCP 上升沿。检查 H4 接线和两片 595 级联。

`u_touch/u_pos/pos[3:0]` 为调试用段索引 0～7，不再是旧版 0～15 插值位置；无触摸时也为 0，须结合 touch 判断，不能单看 pos 判定 P1 被触摸。

## 自检

```powershell
.\sim\run_touch.ps1
.\sim\run_touch.ps1 -Board
```

- `tb_touch`、`tb_touch_first1`：分别检查 ELE0～7、ELE1～8 的初始化、滤波/基线通道切片、八对灯、逐段松手、多段同时触摸、未使用通道忽略，以及 NACK、模块复位、过流、SCL/SDA 卡死恢复。
- `tb_touch_map`：256 种触摸组合、正反向、持续长按、单周期清零、数据过期/离线熄灯，以及在 595 移位中松手后完整锁存全零。
- `tb_touch_speed`：标称 52.5 MHz 时钟与默认 I²C 速率下，检查 SCL 高/低电平最小时间及 2 ms 有效帧间隔。
- `tb_board`：原有键盘、PT8211、音色音量、立体声和帧内计算期限回归。

当前更改前的 src、sim、工程文件和调试位流备份于 `../fpga_backups/before_touch_pairs_20261003/`。仿真从机不模拟真实电极和模拟滤波，通道对应关系、松手效果、邻段串扰及总延迟仍须上板确认。

参考：[NXP MPR121 数据手册](https://www.nxp.com/docs/en/data-sheet/MPR121.pdf)、[TI SN74HC595 数据手册](https://www.ti.com/lit/ds/symlink/sn74hc595.pdf)。

GAO 时钟约束按 [Gowin Software Quick Start Guide 第 3.8 节](https://cdn.gowinsemi.com.cn/SUG918E.pdf)建立：JTAG TCK 与采样时钟异步，分别检查各自时钟域的时序，不按固定相位检查两个独立时钟之间的路径。这不代替用户 RTL 的跨时钟同步设计；本工程触摸和音频计算仍在同一个处理时钟域。

2026-10-03 本次自检结果：tb_touch、tb_touch_first1、tb_touch_map、tb_touch_speed、tb_board 均 PASS，ModelSim 0 errors / 0 warnings。默认参数下有效触摸帧间隔为 2.000059 ms；整机测试中的键盘至数字音频延迟为 3.119291 ms（不是触摸延迟，也不是模拟输出延迟）。

最终构建（2026-10-03 21:27）：Gowin V1.9.12.03 综合、布局布线、GAO 位流生成完成，无 RTL/PNR 警告和错误。工具的用户缓存 sh.log 因环境权限无法写入，但工程内报告、完整构建日志和位流均正常生成。

- 输出：`impl/pnr/ao_0.fs`，生成时间 21:27:30，41,087,430 字节。
- SHA256：`883160AC79819AE62F9A5B124F55C56E7EFA3B51054EC89436EFB2A45DEA68DE`。
- 标称处理时钟 52.500 MHz，报告 Fmax 52.771 MHz；最差 Setup Slack 0.098 ns、Hold Slack 0.181 ns，各时钟域 Setup/Hold 负裕量端点均为 0。时序裕量较小，此结果针对工具标称 OSC 时钟，不等于对实际 OSC 频差和硬件的额外验证。
- 含 GAO 的全工程：Logic 22698/138240、Register 10144/139095、BSRAM 201/340；逻辑锁存器 0。
- 此构建补齐了 GAO TCK 的 20 MHz 与异步时钟组约束。所有接口延迟约束仍保留在同一份 audio.sdc，避免 Gowin 多份 SDC 只使用最后一份。
- 报告：`impl/pnr/synth21.rpt.txt`、`impl/pnr/synth21_tr_content.html`；完整构建日志：`E:/FPGA/touch_review/pairs_final_build.log`。

以上为软件工具验证。本次未向实物下载；八段实际接线、松手清灯和模拟传感器响应待用户上板确认。
