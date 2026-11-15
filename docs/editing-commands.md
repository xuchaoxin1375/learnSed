## 常用编辑命令

`s` 负责替换，但 sed 还能做很多别的事：打印、删除、插入、追加、整行替换、逐字符转换、提前退出、读写文件。这一篇按用途介绍这些命令，先建立“命令表”，再逐类看例子。

多行命令 `n`、`N`、`P`、`D` 只在这里提一下，细节放在[多行处理](multiline.md)。

### 命令速查

| 命令 | 作用 | 备注 |
| --- | --- | --- |
| `p` | 打印当前模式空间 | 常与 `-n` 搭配 |
| `P` | 打印到第一个换行 | 多行处理 |
| `=` | 打印当前输入行号 | 行号单独占一行 |
| `l` | 可视化显示模式空间 | 显示 `$`、制表符、不可打印字符 |
| `F` | 打印当前输入文件名 | **GNU**；标准输入显示 `-` |
| `d` | 删除模式空间，开始下一轮 | 不打印 |
| `D` | 删除到第一个换行，重启脚本 | 多行处理 |
| `a text` | 当前行之后追加文本 | **GNU** 单行形式 |
| `i text` | 当前行之前插入文本 | **GNU** 单行形式 |
| `c text` | 用文本替换当前行或范围 | 范围只输出一份 |
| `y/src/dst/` | 逐字符映射 | 不是正则，集合长度必须相同 |
| `q [code]` | 打印后退出 | 可指定退出码 |
| `Q [code]` | 不打印直接退出 | **GNU** |
| `r file` | 当前行后读入文件内容 | 文件内容进入输出队列 |
| `R file` | 每轮读入文件的一行 | **GNU** |
| `w file` | 把模式空间写入文件 | 文件在脚本开始时截断 |
| `W file` | 把模式空间第一行写入文件 | **GNU** |
| `e [cmd]` | 执行 shell 命令 | **GNU**，有安全风险 |
| `z` | 清空模式空间 | **GNU**；仍然会输出空行 |

### 打印与查看

`p` 已经见过。它打印当前模式空间，不是打印“匹配到的部分”：

```shell
sed -n '/dev\.local/p' examples/data/hosts.txt
```

输出三行完整的主机记录。

`=` 打印当前输入行号：

```shell
sed -n '/dev\.local/=' examples/data/hosts.txt
```

输出：

```shell
7
8
9
```

行号是输入流中的位置，不是匹配次数。配合 `p` 可以同时看行号和内容：

```shell
sed -n '/dev\.local/{=;p}' examples/data/hosts.txt
```

输出：

```shell
7
10.0.0.5        api.dev.local
8
10.0.0.6        db.dev.local      # primary database
9
10.0.0.7        cache.dev.local
```

要把行号和内容放在同一行，可以再接一个 sed：

```shell
sed '=' examples/data/poem.txt | sed 'N;s/\n/\t/'
```

输出：

```shell
1	roses are red
2	violets are blue
3	sed is a stream editor
4	and so are you
```

第一个 sed 把行号单独打印一行，第二个 sed 用 `N` 把下一行拼进来，再把中间的换行换成制表符。

`l` 用来查看不可见字符。它会在行尾显示 `$`，把制表符显示成 `\t`，把不可打印字节显示成八进制转义：

```shell
printf 'a\tb\n' | sed -n 'l'
```

输出：

```shell
a\tb$
```

默认在 70 个字符左右折行。`l 0` 关闭折行，`l 20` 指定宽度：

```shell
printf 'abcdefghijklmnopqrstuvwxyz0123456789\n' | sed -n 'l 10'
```

输出：

```shell
abcdefghi\
jklmnopqr\
stuvwxyz0\
123456789$
```

`l` 对排查行尾空白、制表符和编码问题很有用。不过不同平台和构建对换行的处理可能不同，怀疑 CRLF 时最好再用 `od -An -c` 看原始字节。

`F` 打印当前输入文件名，是 **GNU** 扩展：

```shell
sed -n 'F;p' examples/data/poem.txt
```

输出：

```shell
examples/data/poem.txt
roses are red
examples/data/poem.txt
violets are blue
examples/data/poem.txt
sed is a stream editor
examples/data/poem.txt
and so are you
```

从标准输入读取时，`F` 输出 `-`。

### 删除行

`d` 删除当前模式空间，并立即开始下一轮，不执行后续命令，也不打印：

```shell
sed '/^#/d;/^$/d' examples/data/hosts.txt
```

输出只保留主机记录：

```shell
127.0.0.1       localhost
127.0.1.1       devbox
10.0.0.5        api.dev.local
10.0.0.6        db.dev.local      # primary database
10.0.0.7        cache.dev.local
10.1.0.5        api.prod.local
10.1.0.6        db.prod.local
```

`d` 和 `-n` 的组合容易混淆：

- `sed '2d'` 删除第 2 行，打印其余行。
- `sed -n '2d'` 同样删除第 2 行，但因为没有默认打印，也没有 `p`，所以什么都不输出。
- `sed -n '2!p'` 打印除第 2 行以外的所有行。

最后一种写法和 `2d` 的效果在“只输出”上相同，但语义不同：一个是用 `!` 选择要打印的行，一个是删除不想要的行。写复杂脚本时，选一种并保持一致。

### 插入、追加与整行替换

`a` 在当前行之后追加文本，`i` 在当前行之前插入文本，`c` 用文本替换当前行：

```shell
sed '1i\# generated file' examples/data/poem.txt
```

输出：

```shell
# generated file
roses are red
violets are blue
sed is a stream editor
and so are you
```

```shell
sed '$a\# end of file' examples/data/poem.txt
```

输出：

```shell
roses are red
violets are blue
sed is a stream editor
and so are you
# end of file
```

```shell
sed '2c\replaced line' examples/data/poem.txt
```

输出：

```shell
roses are red
replaced line
sed is a stream editor
and so are you
```

`c` 作用于一个范围时，会把整个范围替换成**一份**文本，而不是每行替换一次：

```shell
sed '2,3c\replaced block' examples/data/poem.txt
```

输出：

```shell
roses are red
replaced block
and so are you
```

GNU sed 允许把文本直接写在命令后面：`sed '1i hello'`。POSIX 写法要求反斜杠加换行：

```shell
sed '1i\
hello' examples/data/poem.txt
```

两种写法在 GNU sed 上都能用。单行形式会**去掉文本开头的空白**；需要保留缩进时，用反斜杠换行形式，或者把空白写进文本的转义里。这个差异在生成 YAML、Markdown 缩进内容时很容易踩到。

`a`、`i`、`c` 的文本会一直延伸到行尾，所以不能在同一行后面继续写命令：

```shell
sed '1a A;1i I' examples/data/poem.txt
```

输出前几行是：

```shell
roses are red
A;1i I
violets are blue
```

`;1i I` 被当成了追加文本。要执行两条命令，用 `-e` 分开：

```shell
sed -e '1a A' -e '1i I' examples/data/poem.txt
```

输出：

```shell
I
roses are red
A
violets are blue
sed is a stream editor
and so are you
```

这也说明 `i` 和 `a` 的输出位置：`i` 在匹配行之前，`a` 在匹配行之后。

### 逐字符转换 y

`y` 把源集合里的字符按位置映射到目标集合：

```shell
printf 'abc\n' | sed 'y/abc/xyz/'
```

输出：

```shell
xyz
```

源集合和目标集合的长度必须相同，否则 sed 报错：

```shell
printf 'abc\n' | sed 'y/ab/xyz/'
```

输出类似：

```shell
sed: -e expression #1, char 9: strings for `y' command are different lengths
```

`y` 不是正则，也不支持 `g` 标志；它对模式空间里的每个字符都做一次映射。常见用途是转换大小写，但**不要写范围**：

```shell
printf 'abc XYZ\n' | sed 'y/a-z/A-Z/'
```

输出：

```shell
Abc XYZ
```

`y` 把 `a-z` 当成 `a`、`-`、`z` 三个字符，而不是 26 个字母。结果只有 `a` 被换成 `A`。要转换整个字母表，写全：

```shell
printf 'Hello, World!\n' | sed 'y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/'
```

输出：

```shell
hello, world!
```

更可靠的做法是用 `tr`：

```shell
printf 'Hello, World!\n' | tr 'A-Z' 'a-z'
```

`tr` 明确支持范围，语义也更直观。

### 提前退出 q 与 Q

`q` 打印当前模式空间（除非用了 `-n`），然后以指定状态退出：

```shell
sed '3q' examples/data/poem.txt
```

输出前三行：

```shell
roses are red
violets are blue
sed is a stream editor
```

`q` 可以带退出码：

```shell
sed '3q 7' examples/data/poem.txt
```

输出前三行，退出码是 `7`。`Q` 是 **GNU** 扩展，退出前不打印：

```shell
sed 'Q 9' examples/data/poem.txt
```

没有任何输出，退出码是 `9`。

`q` 常用于“找到第一条就停”：

```shell
sed -n '/" 5[0-9][0-9] /{p;q}' examples/data/access.log
```

输出第一条 5xx 日志。`-n` 关闭默认打印，`p` 打印匹配行，`q` 立即退出。没有 `q` 时，sed 会继续扫描整个文件。

`q` 会停止处理所有输入文件，不只是当前文件。需要按文件提前结束时，要结合 `-s` 或外层循环。

### 读写文件

`r` 在当前行之后插入文件内容：

```shell
sed '2r examples/data/block.txt' examples/data/poem.txt
```

输出：

```shell
roses are red
violets are blue
# BEGIN app settings
host = 127.0.0.1
port = 8080
# END app settings
sed is a stream editor
and so are you
```

`R` 每轮只读文件的一行，适合把两个文件按行合并。`w` 把模式空间写入文件：

```shell
sed -n '1,2w /tmp/two-lines.txt' examples/data/poem.txt
cat /tmp/two-lines.txt
```

输出：

```shell
roses are red
violets are blue
```

`w` 的目标文件在脚本开始时被创建或截断，即使没有任何行匹配，文件也可能被清空。不要把 `w` 指向重要文件，除非你确认过这个行为。

`W` 只写模式空间的第一行，是 **GNU** 扩展。`r`/`R`/`w`/`W` 在复杂脚本里容易让数据流变得难追踪；能用管道和重定向解决时，优先用管道。

### 执行命令与清空

`e` 执行 shell 命令，是 **GNU** 扩展：

```shell
printf 'echo hi\n' | sed '1e'
```

输出：

```shell
hi
```

`e` 会把模式空间当命令执行，或者执行显式给出的命令。它和 `s///e` 一样有安全风险：如果输入来自不可信来源，等于把输入交给 shell。不要在 Web 表单、日志内容或用户可控文本上随意使用。

`z` 清空模式空间，但仍然输出一个空行：

```shell
sed '2z' examples/data/poem.txt
```

输出：

```shell
roses are red

sed is a stream editor
and so are you
```

`z` 和 `d` 的区别是：`z` 保留这一条记录，只是内容为空；`d` 删除记录，不输出。

### 多行命令预览

`n` 和 `N` 都会读下一行，但方式不同：

- `n` 打印当前模式空间（除非 `-n`），然后用下一行替换它。
- `N` 把下一行追加到当前模式空间，两行之间用换行分隔。

`P` 打印到第一个换行，`D` 删除到第一个换行并重启脚本。它们和 `N` 组合可以实现滑动窗口、合并段落等效果，细节见[多行处理](multiline.md)。

### 练习

- 给 `examples/data/poem.txt` 加一行标题和一行结尾，标题在第一行之前，结尾在最后一行之后。
- 给 `examples/data/hosts.txt` 的每条主机记录加上行号，格式为“行号 + 制表符 + 内容”，跳过注释和空行。
- 用 `c` 把 `examples/data/config.ini` 的 `[logging]` 段整体替换成一行 `# logging disabled`。
- 用 `y` 把 `examples/data/poem.txt` 全部转成大写。提示：先写全字母表，或者用 `tr`。
- 找到 `examples/data/access.log` 中第一条 5xx 记录并停止处理。

<details>
<summary>参考答案</summary>

标题和结尾：

```shell
sed -e '1i\# poem' -e '$a\# the end' examples/data/poem.txt
```

给主机记录加行号：

```shell
sed -e '/^#/d' -e '/^$/d' -e '=' examples/data/hosts.txt | sed 'N;s/\n/\t/'
```

先过滤，再用 `=` 输出行号；第二个 sed 把行号和内容合并到一行。

替换 logging 段：

```shell
sed '/^\[logging\]/,$c\# logging disabled' examples/data/config.ini
```

`$` 表示到文件末尾；`c` 把整个范围替换成一行。

转大写：

```shell
sed 'y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/' examples/data/poem.txt
```

或者：

```shell
tr 'a-z' 'A-Z' < examples/data/poem.txt
```

第一条 5xx 并退出：

```shell
sed -n '/" 5[0-9][0-9] /{p;q}' examples/data/access.log
```

</details>

下一篇：[保持空间与流程控制](hold-space.md)。
