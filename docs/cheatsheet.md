## 速查表

这一篇用于查阅，不替代前面的讲解。命令默认在 GNU sed 4.9 上验证；标记 **GNU** 的写法不要假设 BSD/macOS 支持。

### 调用方式

| 写法 | 作用 |
| --- | --- |
| `sed 'script' file` | 对文件执行脚本，结果写到标准输出 |
| `sed -n 'script' file` | 关闭默认打印，只用显式 `p` 输出 |
| `sed -e 'cmd1' -e 'cmd2' file` | 多个脚本按顺序执行 |
| `sed -f script.sed file` | 从文件读取脚本 |
| `sed -E 'script' file` | 使用 ERE |
| `sed -i 'script' file` | 就地修改，无备份 |
| `sed -i.bak 'script' file` | 就地修改，保留 `.bak` 备份 |
| `sed -s 'script' f1 f2` | 每个文件单独处理，**GNU** |
| `sed -z 'script' file` | 用 NUL 分隔记录，**GNU** |
| `sed -b 'script' file` | 二进制模式读入，保留 CR，**GNU** |
| `sed --debug 'script' file` | 打印内部循环，**GNU** |
| `sed --sandbox 'script' file` | 禁止 `e`、`r`、`w`，**GNU** |
| `sed --version` | 查看版本 |
| `sed --help` | 查看选项摘要 |

`-i` 隐含 `-s`：每个文件单独处理，`$` 是每个文件的最后一行。

### 地址

| 写法 | 匹配 |
| --- | --- |
| `n` | 第 n 行 |
| `$` | 最后一行 |
| `/re/` | 匹配正则的行 |
| `\cREc` | 用 `c` 作正则分隔符 |
| `first~step` | 从 first 开始，每 step 行，**GNU** |
| `a,b` | 从 a 到 b，两端包含 |
| `a,+N` | a 及其后 N 行，**GNU** |
| `a,~N` | a 到下一个 N 的倍数行，**GNU** |
| `0,/re/` | 从开头到第一次匹配，结束正则可匹配首行，**GNU** |
| `addr!cmd` | 对不匹配 addr 的行执行 |
| `addr{cmd1;cmd2}` | 命令块，共享地址 |

范围结束正则是从起始行的**下一行**开始测试的。结束模式不存在时，范围到 EOF。

### 命令

| 命令 | 作用 |
| --- | --- |
| `p` | 打印模式空间 |
| `P` | 打印到第一个换行 |
| `=` | 打印输入行号 |
| `l` | 可视化显示不可打印字符 |
| `F` | 打印当前文件名，**GNU** |
| `d` | 删除模式空间，开始下一轮 |
| `D` | 删除到第一个换行，重启脚本 |
| `a text` | 当前行后追加，**GNU** 单行形式 |
| `i text` | 当前行前插入，**GNU** 单行形式 |
| `c text` | 替换当前行或范围 |
| `y/src/dst/` | 逐字符映射，集合等长 |
| `q [code]` | 打印后退出，可指定退出码 |
| `Q [code]` | 不打印退出，**GNU** |
| `r file` | 当前行后读入文件 |
| `R file` | 每轮读文件一行，**GNU** |
| `w file` | 写模式空间到文件 |
| `W file` | 写第一行到文件，**GNU** |
| `e [cmd]` | 执行 shell，**GNU** |
| `z` | 清空模式空间，**GNU** |
| `n` | 打印后读下一行 |
| `N` | 追加下一行 |
| `b [label]` | 无条件分支 |
| `t [label]` | 替换成功时分支 |
| `T [label]` | 替换失败时分支，**GNU** |
| `:label` | 定义标签 |

### s 命令

```shell
s/regexp/replacement/flags
```

| flag | 作用 |
| --- | --- |
| `g` | 替换所有匹配 |
| 数字 | 只替换第 N 个 |
| 数字加 `g` | 从第 N 个替换到末尾 |
| `p` | 替换成功时打印 |
| `I` / `i` | 忽略大小写，**GNU** |
| `M` / `m` | 多行锚点，**GNU** |
| `e` | 把结果当命令执行，**GNU** |
| `w file` | 替换成功时写入文件 |

替换文本：

| 写法 | 含义 |
| --- | --- |
| `&` | 整个匹配 |
| `\1` 到 `\9` | 捕获组 |
| `\&` | 字面量 `&` |
| `\\` | 字面量反斜杠 |
| `\n` | 换行，**GNU** |
| `\t` | 制表符，**GNU** |
| `\U`、`\L` | 后续转大写/小写，**GNU** |
| `\u`、`\l` | 下一个字符转大写/小写，**GNU** |
| `\E` | 结束大小写转换，**GNU** |

分隔符可以换成任意字符，例如 `s#/var/log#/srv/log#`。

### 正则速查

| 功能 | BRE | ERE |
| --- | --- | --- |
| 任意字符 | `.` | `.` |
| 零次或多次 | `*` | `*` |
| 一次或多次 | `\+` **GNU** | `+` |
| 零次或一次 | `\?` **GNU** | `?` |
| 分组 | `\(...\)` | `(...)` |
| 重复次数 | `\{m,n\}` | `{m,n}` |
| 字符集合 | `[...]` | `[...]` |
| 行首/行尾 | `^` / `$` | `^` / `$` |
| 单词边界 | `\b`、`\<`、`\>` **GNU** | 同左，**GNU** |
| 单词字符 | `\w` **GNU** | 同左，**GNU** |
| 空白 | `\s` **GNU** | 同左，**GNU** |

交替在 ERE 里是 `|`，在 GNU BRE 里是 `\|`。POSIX ERE 不要求支持反向引用；GNU 支持，但跨平台脚本要谨慎。

常用字符类：

- `[[:digit:]]`：数字。
- `[[:alpha:]]`：字母。
- `[[:alnum:]]`：字母和数字。
- `[[:space:]]`：空白。
- `[[:upper:]]` / `[[:lower:]]`：大写/小写。
- `[[:punct:]]`：标点。
- `[[:xdigit:]]`：十六进制数字。

POSIX 正则没有 `\d`、惰性量词、lookaround。需要这些时换 Perl 或 Python。

### 常用单行命令

按行筛选：

```shell
sed -n '10,20p' file.txt
sed -n '$p' file.txt
sed -n '/pattern/p' file.txt
sed -n '/start/,/end/p' file.txt
sed -n '/pattern/!p' file.txt
sed -n '/pattern/=' file.txt
sed -n '/pattern/{p;q}' file.txt
```

删除：

```shell
sed '/^$/d' file.txt
sed '/^#/d' file.txt
sed '1d' file.txt
sed '2,5d' file.txt
sed '/pattern/d' file.txt
```

替换与清理：

```shell
sed 's/old/new/' file.txt
sed 's/old/new/g' file.txt
sed 's/^[[:space:]]*//;s/[[:space:]]*$//' file.txt
sed -E 's/[[:space:]]+/ /g' file.txt
sed 's/\r$//' file.txt
sed -E 's/([0-9]+\.){3}[0-9]+/x.x.x.x/' file.txt
```

格式与编号：

```shell
sed 's/^/  /' file.txt
sed 's/$/;/' file.txt
sed '=' file.txt | sed 'N;s/\n/\t/'
sed '1i\header' file.txt
sed '$a\footer' file.txt
```

多行与保持空间：

```shell
sed -n '1!G;h;$p' file.txt
sed 'G' file.txt
sed 'N;s/\n/ /' file.txt
sed -n '/./{H;$!d};x;s/^\n//;s/\n/ /g;p' file.txt
sed '/^$/{N;/^\n$/D}' file.txt
```

就地修改：

```shell
sed -i.bak 's/old/new/g' file.txt
find /path/to/project -name '*.md' -exec sed -i.bak 's/old/new/g' {} +
```

批量修改前先预览：

```shell
find /path/to/project -name '*.md' -exec grep -l 'old' {} +
```

### GNU 与 BSD/macOS

| 功能 | GNU sed | BSD/macOS sed |
| --- | --- | --- |
| `-i` | `-i` / `-i.bak` | `-i ''` / `-i .bak` |
| `-E` | 支持 | 通常支持 |
| `-r` | 支持 | 不支持 |
| `0,/re/` | 支持 | 不支持 |
| `a,+N`、`a,~N` | 支持 | 不支持 |
| `first~step` | 支持 | 不支持 |
| `\+`、`\?` 与交替写法 | 支持 | 通常不支持 |
| `\w`、`\s`、`\b` | 支持 | 不支持或不同 |
| `a text` 单行 | 支持 | 要求 `a\` 换行 |
| `-s`、`-z` | 支持 | 通常不支持 |
| `Q`、`R`、`W`、`T`、`z`、`F` | 支持 | 通常不支持 |
| `--debug`、`--sandbox` | 支持 | 不支持 |

跨平台脚本优先用 POSIX 子集，或者显式依赖 GNU sed 并在开头检查版本。

### 退出码

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `1` | 脚本或参数错误 |
| `2` | 文件打不开 |
| `4` | 读写出错 |

`q` 和 `Q` 可以指定退出码。管道场景用 `set -o pipefail` 或检查 `PIPESTATUS`。

### 调试

```shell
sed --debug 's/old/new/' file.txt
sed -n 'l' file.txt
od -An -c file.txt
sed -n '/pattern/=' file.txt
diff -u original.txt modified.txt
locale
LC_ALL=C sed 's/./X/g' file.txt
```

`--debug` 看模式空间和命令，`l` 和 `od` 看不可见字符，`=` 看行号，`diff` 看改动范围。

### 什么时候不要用 sed

- JSON、XML、YAML：用 `jq`、`yq` 或对应语言的库。
- 带引号的 CSV：用 Python 的 `csv` 模块。
- 字段聚合、算术、排序：用 `awk`、`sort`、`uniq`。
- 复杂状态机、递归、错误处理：用 Python、Perl 或 Go。
- 二进制文件：用专用工具。
- 交互式编辑：用编辑器。

上一篇：[排错与常见陷阱](troubleshooting.md)。下一篇：[综合练习](capstone.md)。
