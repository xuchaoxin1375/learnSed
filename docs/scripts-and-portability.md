## 脚本化与可移植性

一行 sed 命令适合临时处理。需要重复使用、审查和测试时，把脚本写进文件更可靠：不用和 shell 引号搏斗，也能在版本库里看到每次修改。

这一篇讲四件事：如何组织 sed 脚本、如何安全地写回文件、GNU 与 BSD/macOS 的差异，以及什么时候应该换工具。

### 把脚本写进文件

用 `-f` 读取脚本文件：

```shell
sed -f examples/scripts/clean-hosts.sed examples/data/hosts.txt
```

脚本文件里一行一条命令，`#` 开头的整行是注释：

```sed
# 删除整行注释和空行
/^[[:space:]]*#/d
/^[[:space:]]*$/d
# 压缩空白
s/[[:space:]]\+/ /g
```

`-f` 的好处是 shell 不再参与解析，反斜杠、引号和 `$` 都按 sed 的规则处理。脚本文件也更容易做代码审查和单元测试。

为可移植性，注释单独占一行，不要写在命令末尾。GNU sed 接受某些行尾注释，POSIX 不保证。

脚本第一行如果是 `#n`，sed 会关闭默认输出，效果类似 `-n`：

```shell
printf '#n\ns/a/A/\n' > /tmp/no-print.sed
printf 'a\nb\n' | sed -f /tmp/no-print.sed
```

没有任何输出。`#n` 必须是脚本最开头的两个字符；它后面可以跟其他内容，但 `#n` 本身要完整。

多个 `-e` 和 `-f` 可以混用，按出现顺序执行：

```shell
sed -e 's/a/A/' -f /tmp/extra.sed -e 's/b/B/' input.txt
```

如果只是两三条命令，`-e` 足够；命令多了、需要注释和复用，就写成文件。

### 退出码

sed 的退出码可以用来判断成功与失败：

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功完成 |
| `1` | 命令行参数或脚本有语法错误 |
| `2` | 无法打开命令行指定的文件 |
| `4` | 处理过程中发生 I/O 错误 |

`q` 和 `Q` 可以指定退出码，覆盖默认的 `0`：

```shell
sed '3q 7' examples/data/poem.txt
printf 'exit=%s\n' "$?"
```

输出前三行，退出码是 `7`。

在 shell 脚本里，不要只看 sed 是否打印了内容；检查 `$?`，并确保前面的命令失败不会被后面的成功掩盖。bash 脚本可以这样写：

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! sed -f clean.sed input.txt > output.txt; then
  echo "sed failed" >&2
  exit 1
fi
```

`set -e` 不是万能的，管道和条件语句里的行为有细节；需要严格处理时显式检查每一步的退出码。sed 本身没有“预览模式”，安全网要靠备份、差异检查和测试。

### 安全地就地修改

`-i` 会直接改文件，出错时可能没有第二次机会。建议按下面的顺序操作：

1. 先不带 `-i` 运行，把结果输出到终端或临时文件。
2. 在小样本上确认匹配范围和替换结果。
3. 用 `-i.bak` 保留备份，或先复制一份。
4. 用 `diff -u` 比较修改前后。
5. 确认无误后再删除备份；如果文件在 Git 里，用 `git diff` 检查。

一个完整流程：

```shell
cp examples/data/config.ini /tmp/config.ini
sed -i.bak '/^\[server\]/,/^\[client\]/{s/^port = .*/port = 9090/}' /tmp/config.ini
diff -u examples/data/config.ini /tmp/config.ini
```

`diff` 的退出码 `1` 表示有差异，不是命令失败。在 `set -e` 脚本里直接调用 `diff` 要注意这一点，可以写成 `diff -u ... || true`，或者只把差异当预期结果处理。

`-i` 的几个关键行为：

- GNU sed 的 `-i` **隐含 `-s`**：每个文件单独处理，`$` 是每个文件的最后一行，行号和范围按文件重置。这对 `find ... -exec sed -i ...` 很重要。
- `-i.bak` 会为每个文件生成同名备份。例如 `a.txt` 生成 `a.txt.bak`。
- `-i` 不带后缀时没有备份。
- `-i` 写回的是 sed 的输出。`-n` 会关闭自动输出，`sed -n -i 's/a/A/' file` 会把文件清空。用 `-i` 时不要随手加 `-n`。
- GNU sed 的 `-i` 通常创建临时文件再替换原文件；硬链接会被拆开，符号链接的默认行为也可能与直觉不同。需要编辑符号链接目标时，用 **GNU** 的 `--follow-symlinks`，并在操作前用 `ls -l` 确认链接关系。
- macOS 的 BSD sed 要求 `-i` 带参数：`sed -i '' 's/foo/bar/' file` 才是不保留备份的写法。GNU 的 `-i.bak` 在 BSD sed 上不通用。跨平台脚本优先显式调用 `gsed`。

批量替换一个目录里的 Markdown 文件，可以先预览命中文件：

```shell
find /path/to/project -name '*.md' -exec grep -l 'old-name' {} +
```

确认后再替换：

```shell
find /path/to/project -name '*.md' -exec sed -i.bak 's/old-name/new-name/g' {} +
```

`-exec ... +` 会把多个文件一次传给 sed。因为 `-i` 隐含 `-s`，每个文件独立处理；备份也会逐文件生成。替换后检查 `git diff`，确认没有误伤代码块、链接或示例。

### -s、-z 与调试选项

`-s` 或 `--separate` 把多个输入文件视为独立流：

- 行号按文件重置。
- `$` 是每个文件的最后一行。
- 范围不会跨文件。
- 保持空间在 GNU sed 4.9 上也会按文件重置；不要依赖它跨文件保存状态。

```shell
sed -n -s '$p' examples/data/poem.txt examples/data/hosts.txt
```

输出两个文件的最后一行。

`-z` 把记录分隔符改成 NUL，适合 `find -print0` 和 `xargs -0` 的数据。它是 **GNU** 扩展，细节见[多行处理](multiline.md)。

`--debug` 打印 sed 的内部循环，适合理解脚本和排查地址问题。`--sandbox` 禁止 `e`、`r`、`w` 等能执行命令或写文件的命令，适合运行不完全信任的脚本：

```shell
sed --sandbox 's/a/b/' examples/data/poem.txt
```

两者都是 **GNU** 扩展，BSD sed 不支持。

### GNU 与 BSD/macOS 的差异

| 功能 | GNU sed | BSD/macOS sed |
| --- | --- | --- |
| 就地修改 | `-i` 或 `-i.bak` | `-i ''` 或 `-i .bak`，后缀参数必需 |
| 扩展正则选项 | `-E`，`-r` 是别名 | 通常只有 `-E` |
| `0,/re/` | 支持 | 不支持 |
| `addr,+N`、`addr,~N` | 支持 | 不支持 |
| `first~step` | 支持 | 不支持 |
| `\w`、`\s`、`\b`、`\<`、`\>` | 支持 | 不支持或行为不同 |
| BRE 的 `\+`、`\?` 与交替写法 | 支持 | 通常不支持 |
| `a text` 单行形式 | 支持 | 要求 `a\` 加换行 |
| `-z`、`-s` | 支持 | 通常不支持 |
| `Q`、`R`、`W`、`T`、`z`、`F` | 支持 | 通常不支持 |
| `--debug`、`--sandbox` | 支持 | 不支持 |

这张表是常见差异，不是所有 BSD 变体的完整清单。FreeBSD、OpenBSD、macOS 自带版本之间也可能不同；以目标机器上的 `sed --version` 或手册为准。

### 可移植写法

如果脚本必须在 BSD/macOS 上运行，优先使用 POSIX 子集：

- `-n`、`-e`、`-f`，以及较新 POSIX 支持的 `-E`。
- `p`、`d`、`s`、`y`、`a`/`i`/`c` 的反斜杠换行形式、`r`/`w`、`b`/`t`、`:label`、`q`、`=`、`l`。
- BRE 的 `\(...\)`、`\{m,n\}`、`^`、`$`、`.`、`*`、`[...]`。
- 不使用 `-i`，或者把备份和写回交给外层脚本处理。

需要大小写转换、单词边界、NUL 记录、`0,/re/` 这类 GNU 特性时，有两个选择：

- 明确依赖 GNU sed，在脚本开头检查版本，失败时给出安装提示。
- 换用 `awk`、`perl` 或 Python，把可移植性交给更合适的工具。

示例：把 GNU 的 `\U` 转大写改成可移植写法：

```shell
printf 'hello\n' | sed 's/.*/\U&/'
```

GNU sed 输出 `HELLO`。BSD sed 不认识 `\U`，结果会不同。可移植版本可以用 `tr`：

```shell
printf 'hello\n' | tr 'a-z' 'A-Z'
```

### 性能与工具选择

sed 通常很快，因为它是流式的，逐行处理，内存占用小。但有些写法会改变这个前提：

- `N` 循环、`-z` slurp、保持空间去重会把大量内容放进内存。
- `-i` 需要额外的临时文件空间，文件越大，磁盘占用越高。
- `LC_ALL=C` 对纯 ASCII 数据通常更快，但会改变多字节字符的匹配语义；不要为了速度盲目设置。
- 复杂的正则、嵌套量词和大量分支可能让匹配变慢；先用小样本和 `time` 测，不要凭感觉优化。
- 大量文件逐个启动 sed 有进程开销；`find ... -exec ... +` 或 `xargs` 可以批量传入，但要注意 `-i` 的逐文件语义。

选择工具时，按任务性质而不是个人偏好：

| 任务 | 更合适的工具 |
| --- | --- |
| 按行替换、删除、插入 | sed |
| 按字段筛选、聚合、计算 | awk |
| 复杂正则、Unicode、JSON | Perl、Python、jq |
| 排序、去重、计数 | sort、uniq、awk |
| 二进制或需要精确字节控制 | 专用工具或编程语言 |

sed 的优势是短、快、管道友好；它的短板是状态管理和结构化数据。把 sed 用在它擅长的场景，脚本会更可靠。

### 练习

- 把“删除注释和空行、压缩空白”写成一个 `.sed` 文件，用 `-f` 处理 `examples/data/hosts.txt`。
- 复制 `examples/data/config.ini` 到 `/tmp`，用 `-i.bak` 只改 `[server]` 段的端口，再用 `diff -u` 验证。
- 写一个 bash 包装脚本，检查 `sed --version` 是否包含 `GNU sed`，不是就退出并提示安装 `gsed`。
- 把一条使用 `\U` 的 GNU 命令改成不依赖 GNU 的写法。
- 解释为什么 `sed -n -i 's/a/A/' file` 会把文件清空。

<details>
<summary>参考答案</summary>

清理脚本可以写成：

```sed
/^[[:space:]]*#/d
/^[[:space:]]*$/d
s/[[:space:]]\+/ /g
```

保存为 `clean-hosts.sed` 后运行：

```shell
sed -f clean-hosts.sed examples/data/hosts.txt
```

改端口并验证：

```shell
cp examples/data/config.ini /tmp/config.ini
sed -i.bak '/^\[server\]/,/^\[client\]/{s/^port = .*/port = 9090/}' /tmp/config.ini
diff -u examples/data/config.ini /tmp/config.ini
```

版本检查可以写成：

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! sed --version 2>&1 | grep -q 'GNU sed'; then
  echo "GNU sed is required; install gnu-sed and use gsed" >&2
  exit 1
fi
```

GNU 的大小写转换可以用 `tr` 替代：

```shell
printf 'hello\n' | tr 'a-z' 'A-Z'
```

`sed -n -i 's/a/A/' file` 清空文件，是因为 `-i` 写回 sed 的输出，而 `-n` 关闭了默认输出；脚本里又没有 `p`，所以没有任何行被写回。

</details>

下一篇：[实战案例](recipes.md)。
