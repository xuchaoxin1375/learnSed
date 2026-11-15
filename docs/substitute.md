## 替换命令 s

`s` 是 sed 最常用的命令，但它不是“在文件里查找并替换”。它只在**当前模式空间**里做替换：找到正则匹配的片段，用替换文本换掉，然后继续执行脚本。文件是否改变，取决于你有没有用 `-i`。

理解 `s` 需要同时看清三件事：匹配哪一段、替换成什么、替换几次。

### 基本形式

```shell
s/regexp/replacement/flags
```

- `regexp` 是正则表达式，不是固定字符串。
- `replacement` 是替换文本，里面可以引用匹配到的内容。
- `flags` 控制替换次数、大小写、是否打印等，可以省略。
- 三个部分用一个分隔符隔开。习惯上用 `/`，但分隔符可以是任意字符。

最简单的替换：

```shell
printf 'red red red\n' | sed 's/red/blue/'
```

输出：

```shell
blue red red
```

默认只替换**每行的第一个**匹配。要替换一行里的所有匹配，加 `g`：

```shell
printf 'red red red\n' | sed 's/red/blue/g'
```

输出：

```shell
blue blue blue
```

### 替换第几个匹配

在 `s` 后面写数字，可以只替换指定序号：

```shell
printf 'red red red\n' | sed 's/red/blue/2'
```

输出：

```shell
red blue red
```

数字和 `g` 组合时，表示“从第 N 个开始，替换到末尾”：

```shell
printf 'red red red\n' | sed 's/red/blue/2g'
```

输出：

```shell
red blue blue
```

如果一行里没有第 N 个匹配，替换不会发生，也不会报错。写脚本时不要假设“写了 `3` 就一定会有第三次替换”。

### flags 一览

| flag | 含义 | 备注 |
| --- | --- | --- |
| `g` | 替换所有匹配 | 不加时只替换第一个 |
| 数字 | 只替换第 N 个匹配 | 例如 `2` 只替换第二个 |
| 数字加 `g` | 从第 N 个匹配替换到末尾 | 例如 `2g` |
| `p` | 发生替换时打印模式空间 | 常与 `-n` 搭配，否则会重复输出 |
| `i` / `I` | 忽略大小写 | **GNU**；推荐写 `I` |
| `m` / `M` | 多行模式，让 `^`/`$` 匹配内嵌换行前后 | **GNU**；配合 `N` 使用 |
| `e` | 把替换结果当 shell 命令执行，用输出替换模式空间 | **GNU**；有安全风险 |
| `w file` | 发生替换时把模式空间写入文件 | 文件在脚本开始时被创建或截断 |

`p` 的行为值得单独强调。下面两条命令输出不同：

```shell
printf 'a\nb\n' | sed 's/a/A/p'
```

输出：

```shell
A
A
b
```

第一条命中的行被打印了两次：一次是 `p`，一次是每轮结束时的默认打印。加上 `-n` 后只保留 `p` 的输出：

```shell
printf 'a\nb\n' | sed -n 's/a/A/p'
```

输出：

```shell
A
```

所以在过滤场景里，`-n` 和 `p` 通常成对出现。

### 替换文本里的特殊写法

替换文本不是普通字符串，它有自己的转义规则。

| 写法 | 含义 |
| --- | --- |
| `&` | 整个匹配到的文本 |
| `\1` 到 `\9` | 第 1 到第 9 个捕获组 |
| `\&` | 字面量 `&` |
| `\\` | 字面量反斜杠 |
| `\n` | 换行符，**GNU** 支持 |
| `\t` | 制表符，**GNU** 支持 |
| `\U`、`\L` | 后续文本转大写/小写，**GNU** |
| `\u`、`\l` | 下一个字符转大写/小写，**GNU** |
| `\E` | 结束大小写转换，**GNU** |

用 `&` 给整行加引号：

```shell
printf 'hello\n' | sed 's/.*/"&"/'
```

输出：

```shell
"hello"
```

用捕获组重排字段：

```shell
printf 'one two three\n' | sed 's/\([^ ]*\) \([^ ]*\)/\2 \1/'
```

输出：

```shell
two one three
```

BRE 的捕获组要写成 `\(...\)`，替换时用 `\1`、`\2` 引用。使用 `-E` 后可以写成 `(...)`，可读性更好：

```shell
printf 'one two three\n' | sed -E 's/([^ ]+) ([^ ]+)/\2 \1/'
```

`&` 是替换文本里的特殊字符，不是正则的一部分。它表示“整个匹配到的文本”：

```shell
printf 'abc\n' | sed 's/b/[&]/'
```

输出：

```shell
a[b]c
```

替换文本 `[&]` 里的 `&` 展开为匹配到的 `b`，所以结果是 `a[b]c`。

如果想让输出里出现字面量 `&`，要写成 `\&`。对比下面两条命令：

```shell
printf 'abc\n' | sed 's/b/[&]/'
printf 'abc\n' | sed 's/b/[\&]/'
```

输出：

```shell
a[b]c
a[&]c
```

`&` 在 shell 里也有特殊含义（放在命令末尾会转入后台），单引号会保护它；这里多出的内容来自 sed 的替换文本解析。看到输出里多出匹配内容时，先检查替换文本里的 `&` 是不是忘了转义。

### 大小写转换

GNU sed 可以在替换文本里转换大小写：

```shell
printf 'hello WORLD\n' | sed 's/\(hello\) \(world\)/\U\1\E \L\2\E/I'
```

输出：

```shell
HELLO world
```

`I` 让 `world` 也能匹配大写的 `WORLD`；`\U` 开始转大写，`\E` 结束；`\L` 开始转小写。只转换下一个字符时用 `\u` 和 `\l`：

```shell
printf 'hello world\n' | sed 's/\w\+/\u&/g'
```

输出：

```shell
Hello World
```

`\w` 是 GNU 的单词字符类，通常等价于 `[[:alnum:]_]`；具体范围受 locale 影响。可移植脚本里写成 `[[:alnum:]_]\+` 更稳。

### 换行与制表符

替换文本里的 `\n` 会插入一个换行。它常用于把一行的多个字段拆成多行：

```shell
printf 'a,b,c\n' | sed 's/,/\n/g'
```

输出：

```shell
a
b
c
```

反过来，如果模式空间里已经有换行（例如前面用了 `N`），可以在正则里匹配 `\n` 并替换掉：

```shell
printf 'a\nb\n' | sed 'N;s/\n/+/'
```

输出：

```shell
a+b
```

注意：**普通输入行的行尾换行不在模式空间里**。`s/\n/+/` 不会把两行输入合成一行，除非你先用 `N`、`G` 等命令把下一行读进模式空间。这是初学者最常见的误解之一。

`\t` 在 GNU sed 的替换文本里表示制表符：

```shell
printf 'a,b\n' | sed 's/,/\t/'
```

输出中的逗号变成一个制表符。

### 分隔符

当正则或替换文本里含 `/` 时，继续用 `/` 会让脚本满是反斜杠：

```shell
printf 'a/b/c\n' | sed 's/a\/b/x/'
```

输出：

```shell
x/c
```

换一个分隔符更清楚。`#` 和 `|` 都很常用：

```shell
printf 'a/b/c\n' | sed 's#a/b#x#'
printf '/var/log/app.log\n' | sed 's|/var/log|/srv/log|'
```

输出：

```shell
x/c
/srv/log/app.log
```

分隔符只影响书写，不改变正则语义。选择分隔符时，挑一个不会在正则和替换文本里大量出现的字符。

### 正则匹配的是模式空间

`s` 只处理当前模式空间。它不会跨行搜索，除非你已经用 `N` 把下一行拼进来。它也不会回头处理已经输出过的行。

这意味着两件事：

- 想替换“整个文件里的所有匹配”，需要让 sed 逐行处理，并在每行加 `g`。
- 想替换“跨行的模式”，要先解决把多行放进同一个模式空间的问题，或者换用支持多行模式的工具。

GNU 的 `M` flag 可以让 `^` 和 `$` 匹配模式空间内部换行前后的位置：

```shell
printf 'a\nb\n' | sed 'N;s/^/X/Mg'
```

输出：

```shell
Xa
Xb
```

不加 `M` 时，`^` 只匹配整个模式空间的开头：

```shell
printf 'a\nb\n' | sed 'N;s/^/X/g'
```

输出：

```shell
Xa
b
```

多行处理会在后面的章节展开。这里先记住：`M` 改变的是锚点的匹配位置，不改变记录如何被读入。

### 就地修改与备份

默认的 `s` 只把结果写到标准输出。要修改文件，用 `-i`：

```shell
cp examples/data/dirty.txt /tmp/dirty.txt
sed -i.bak 's/8080/9090/' /tmp/dirty.txt
```

`-i.bak` 表示就地修改，并把原文件保存为 `/tmp/dirty.txt.bak`。检查修改后的文件：

```shell
sed -n '/port/p' /tmp/dirty.txt
```

输出：

```shell
server.port = 9090
```

检查备份：

```shell
sed -n '/port/p' /tmp/dirty.txt.bak
```

输出：

```shell
server.port = 8080
```

`-i` 不带后缀时不保留备份：

```shell
sed -i 's/8080/9090/' /tmp/dirty.txt
```

这条命令执行后，原始内容就没有了。除非文件在版本控制里，或者你确定可以重建，否则先用 `-i.bak` 或复制一份。

关于 `-i` 的几个边界：

- GNU sed 的 `-i` 会创建临时文件再替换原文件。它通常能保留权限，但不保证保留硬链接关系；硬链接会被拆开。
- 对符号链接使用 `-i` 时，GNU sed 默认会用普通文件替换链接本身，而不是修改链接指向的目标。需要修改目标时用 **GNU** 的 `--follow-symlinks`，或者先解析真实路径。这个行为依赖文件系统和平台，操作前用 `ls -l` 确认。
- macOS 自带的 BSD sed 要求 `-i` 带一个参数，常见写法是 `sed -i '' 's/foo/bar/' file`。GNU sed 的 `-i.bak` 写法在 BSD sed 上会报错。跨平台脚本要么检测版本，要么显式使用 `gsed`。
- `-i` 与 `-n` 组合非常危险：`-i` 写回的是 sed 的输出，而 `-n` 关闭了自动输出。`sed -n -i 's/a/A/' file` 会让文件变成空文件，因为没有任何行被输出。需要写回时，要么不加 `-n`，要么在 `-n` 脚本里显式 `p` 出每一行。执行前先用不带 `-i` 的命令预览。

### 引号与 shell 变量

sed 脚本里充满 `$`、`*`、`\`、`&`，引用方式会直接影响结果。

**默认用单引号**：

```shell
sed 's/$/;/' examples/data/poem.txt
```

单引号里的内容原样传给 sed，shell 不做变量展开、命令替换或通配符展开。脚本里出现 `$` 锚点、`&`、反斜杠时，单引号最安全。

需要把 shell 变量塞进替换文本时，用双引号：

```shell
NAME=Alice
ORDER_ID=42
EMAIL=alice@example.com
sed -e "s/{{NAME}}/$NAME/" -e "s/{{ORDER_ID}}/$ORDER_ID/" -e "s/{{EMAIL}}/$EMAIL/" examples/data/template.txt
```

输出：

```shell
Hello, Alice!
Order 42 is ready.
Contact: alice@example.com
```

变量赋值要单独成行，再运行 `sed`。下面这种写法不会把值带进双引号：

```shell
NAME=Alice sed "s/{{NAME}}/$NAME/" examples/data/template.txt
```

双引号在 `sed` 启动前就由 shell 展开了，此时 `NAME` 还没有赋值，替换结果会是空字符串。正确做法是先赋值，再运行 `sed`。

如果变量值里含 `/`，换一个分隔符：

```shell
OLD=/var/log
NEW=/srv/log
sed "s|$OLD|$NEW|" examples/data/config.ini
```

如果变量值里含 `&`、反斜杠或分隔符本身，问题就不只是引号了。这些字符在替换文本里有特殊含义，直接拼接会改变结果：

```shell
printf 'x\n' | sed 's/x/A&B/'
```

输出：

```shell
AxB
```

`&` 被展开成匹配到的 `x`，所以不是字面量 `A&B`。处理用户输入或文件名时，不要直接把它们拼进 sed 脚本。需要可靠的字面量替换时，用 Python 的 `str.replace`、`awk` 的 `gsub` 并正确转义，或者先对输入做转义。

### 常见错误

- **忘记 `g`**：只替换了每行第一个匹配。
- **以为 `s` 会改文件**：没有 `-i` 时只写标准输出。
- **在 BRE 里用 `(...)` 和 `+`**：它们会被当成字面字符；用 `\(...\)`、`\+`，或者加 `-E`。
- **替换文本里的 `&` 没转义**：输出里多出匹配内容。
- **用 `/` 做分隔符又不转义路径里的 `/`**：脚本报错或匹配错位。
- **以为 `\n` 能匹配输入行尾**：行尾换行不在模式空间里；先 `N`。
- **双引号里的 `$` 被 shell 展开**：需要字面量 `$` 时用单引号或转义。
- **`s///p` 没加 `-n`**：命中行输出两遍。
- **`-i` 没有备份**：替换错了无法直接恢复。

### 练习

- 把 `examples/data/poem.txt` 中每行的第一个 `e` 换成 `E`，再换成全部 `e`。
- 把 `examples/data/users.csv` 的前两列交换，保留其余列。
- 给 `examples/data/poem.txt` 的每一行加上 `>> ` 前缀。
- 把 `examples/data/users.csv` 的逗号替换成制表符。这个做法在什么情况下会出错？
- 把 `examples/data/config.ini` 里的 `/var/log/app.log` 改成 `/srv/log/app.log`，分别用 `#` 和 `|` 作为分隔符。
- 复制 `examples/data/dirty.txt` 到 `/tmp`，用 `-i.bak` 把 `8080` 改成 `9090`，然后比较原文件和备份。

<details>
<summary>参考答案</summary>

第一个 `e`：

```shell
sed 's/e/E/' examples/data/poem.txt
```

全部 `e`：

```shell
sed 's/e/E/g' examples/data/poem.txt
```

交换前两列：

```shell
sed -E 's/^([^,]+),([^,]+),/\2,\1,/' examples/data/users.csv
```

加前缀：

```shell
sed 's/^/>> /' examples/data/poem.txt
```

逗号转制表符：

```shell
sed 's/,/\t/g' examples/data/users.csv
```

如果字段本身带引号且引号内有逗号，这个做法会把字段内部的逗号也替换掉，破坏 CSV 结构。简单、无引号的 CSV 才适合这样处理。

路径替换：

```shell
sed 's#/var/log/app.log#/srv/log/app.log#' examples/data/config.ini
sed 's|/var/log/app.log|/srv/log/app.log|' examples/data/config.ini
```

就地修改并比较：

```shell
cp examples/data/dirty.txt /tmp/dirty.txt
sed -i.bak 's/8080/9090/' /tmp/dirty.txt
sed -n '/port/p' /tmp/dirty.txt
sed -n '/port/p' /tmp/dirty.txt.bak
```

输出分别是 `server.port = 9090` 和 `server.port = 8080`。

</details>

下一篇：[sed 的正则表达式](regex.md)。
