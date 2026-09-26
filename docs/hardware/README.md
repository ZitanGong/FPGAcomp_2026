# 引脚核对资料

来源为用户提供的 `Tang_Mega_NEO_Dock-138K_31005_Schematics.pdf` 与板卡引脚图。保留与当前接线相关的图片，以及 MS5351M 原厂寄存器手册。

- `sch-07.png`：核心板连接，V13=USR_CLK_IN、V10=FAN_EN；AA14=CAM_TWI.SCL、Y13=CAM_TWI.SDA，138K 的 Bank 5 为 3.3V。
- `sch-18.png`：MS5351 CLK2 经 R40 到 USR_CLK_IN；晶体为 25MHz，但 CLK2 是可配置输出，不能据此推断输出频率。
- `sch-17.png`：FPGA CAM_TWI 经 U26（PCA9306）转换电平，2.5V 一侧通过 R180/R182 连接 DBG_TWI，因而按原理图存在 FPGA 配置 MS5351 的通路。R146/R147 标为不装，不能假定绕过 U26；实际器件装配和总线连通仍待核实。
- `sch-10.png`：PT8211、耳放和耳机检测，BCK/WS/DIN=Y17/AB17/AA16，PA_EN=AB16、低有效。
- `sch-19.png`、`pinout.png`：扩展接口与针脚位置。

原附件路径：`D:\微信\xwechat_files\wxid_5rudxgqvfxwo32_a045\msg\file\2026-09\Tang_Mega_NEO_Dock-138K_31005_Schematics.pdf`。

约束依据是该 31005 附件及已验证的键盘接线。V13 的外部时钟输入尚待新版本上板测量确认，不能把约束文件里出现 V13 当作实物测频结果。

- `MS5351M_regs.pdf`：瑞盟 MS5351M V1.1（2020-06-25），寄存器表、I²C 地址、PLL/DIV 参数公式及状态定义。下载来源为 https://www.ftelectronic.com/Public/Upload/news/20200822/5f408c820006f.pdf 。
