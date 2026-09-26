# Tang Mega NEO 138K 实时多音色合成器

version:2026.9.26

当前 `impl/pnr/synth21.fs` 只通过重排 `rom/notes.hex` 修改 SW 音符对应关系；扫描、消抖和按键状态逻辑保持不变。

三行 Do～Si：SW5/6/7/1/2/3/4、SW12/13/14/8/9/10/11、SW19/20/21/15/16/17/18。

`impl/pnr/synth21_known_good.fs` 是修改前已实测有声的回退位流。
