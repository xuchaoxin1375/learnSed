## sed 的正则表达式

sed 的地址和 `s` 命令都依赖正则表达式。sed 使用的是 **POSIX 正则**，不是 PCRE，也不是 JavaScript 正则。它默认使用 **BRE**(Basic Regular Expression, 基本正则表达式)，加 `-E` 后使用 **ERE**(Extended Regular Expression, 扩展正则表达式)。

这一篇只讲 sed 里真正会用到的部分：哪些字符有特殊含义、BRE 和 ERE 怎么切换、贪心匹配会带来什么问题，以及 GNU 扩展和可移植性的边界。

### BRE 与 ERE 的差别

同样的目标，两种方言的写法不同：

| 功能 | BRE 写法 | ERE 写法 |
| --- | --- | --- |
| 分组 | `\(...\)` | `(...)` |
| 重复次数 | `\{m,n\}` | `{m,n}` |
| 一个或多个 | `\+`，**GNU** | `+` |
| 零个或一个 | `\?`，**GNU** | `?` |
| 交替 | <code>\&#124;</code>，**GNU** | <code>&#124;</code> |

在 BRE 里，`( ) { } + ? |` 默认是普通字符；要获得特殊含义，通常要加反斜杠。ERE 反过来：这些字符默认有特殊含义，要匹配字面量才需要转义。

这也是为什么很多 sed 命令看起来“满是反斜杠”。加上 `-E` 通常能让脚本更易读：

```shell
printf '2025-10-10\n' | sed 's/\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)/\3.\2.\1/'
```

输出：

```shell
10.10.2025
```

用 ERE 写同样的逻辑：

```shell
printf '2025-10-10\n' | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3.\2.\1/'
```

输出相同，但分组和量词都少了一层反斜杠。

`-r` 是 GNU 对 `-E` 的旧别名。新脚本优先写 `-E`，可移植性更好。

### 字符与转义

正则里的元字符包括：

- `.`：匹配任意一个字符。
- `*`：匹配前一个元素零次或多次。
- `[...]`：字符集合。
- `^`：匹配模式空间开头。
- `$`：匹配模式空间结尾。
- `\`：转义下一个字符。
- BRE 里的 `\(`、`\)`、`\{`、`\}`，ERE 里的 `(`、`)`、`{`、`}`。

要匹配字面量的点号，写 `\.`：

```shell
sed -n '/dev\.local/p' examples/data/hosts.txt
```

如果写成 `/dev.local/`，点号会匹配任意字符，`devXlocal` 也会命中。这类“看起来能跑、边界却不对”的正则，在批量修改里很容易造成误伤。

反斜杠本身要写 `\\`。在 shell 单引号里，`\\` 会原样传给 sed；在双引号里，shell 可能先处理一层，实际到达 sed 的反斜杠数量会变。拿不准时用单引号，或者先用 `printf` 做最小实验。

### 字符集合与字符类

方括号表示“其中任意一个字符”：

```shell
printf 'a1 B2\t!\n' | sed -n 's/[[:digit:]]/D/gp'
```

输出：

```shell
aD BD	!
```

`[[:digit:]]` 是 POSIX 字符类，匹配数字。常用字符类还有：

| 字符类 | 含义 |
| --- | --- |
| `[[:alpha:]]` | 字母 |
| `[[:alnum:]]` | 字母和数字 |
| `[[:digit:]]` | 数字 |
| `[[:space:]]` | 空白字符，包括空格、制表符、换行 |
| `[[:upper:]]` / `[[:lower:]]` | 大写/小写字母 |
| `[[:punct:]]` | 标点符号 |
| `[[:xdigit:]]` | 十六进制数字 |

在方括号里，`^` 放在最前面表示取反：

```shell
printf 'a b\tc\n' | sed -n 's/[^[:space:]]/X/gp'
```

输出：

```shell
X X	X
```

`]` 要放在方括号的第一位才是字面量；`-` 放在开头或结尾才是字面量。比如 `[]a-]` 匹配 `]`、`a` 或 `-`。这些边界不常写，但读别人的正则时会遇到。

字符类的匹配范围受 locale 影响。`[a-z]` 在有些 locale 下会包含带重音的字母，甚至产生意料之外的排序结果；需要严格的 ASCII 范围时，可以临时设置 `LC_ALL=C`，或者使用 `[[:lower:]]` 并确认 locale。

### 量词与贪婪

`*`、`+`、`?` 和 `{m,n}` 控制前一个元素的重复次数：

```shell
printf 'color\ncolour\n' | sed -n '/colou\?r/p'
```

输出：

```shell
color
colour
```

`\?` 表示前面的 `u` 出现零次或一次。ERE 写作 `colou?r`：

```shell
printf 'color\ncolour\n' | sed -nE '/colou?r/p'
```

`+` 表示一次或多次。BRE 里要写 `\+`，否则 `+` 是普通字符：

```shell
printf 'aaab\na+b\n' | sed -n '/a+b/p'
```

输出：

```shell
a+b
```

这条正则匹配的是字面量 `a+b`。要匹配“一个或多个 `a` 后跟 `b`”，写：

```shell
printf 'aaab\na+b\n' | sed -n '/a\+b/p'
```

输出：

```shell
aaab
```

`{m,n}` 在 BRE 里要写成 `\{m,n\}`。`\{3\}` 表示恰好三次，`\{2,\}` 表示至少两次，`\{2,4\}` 表示两到四次。

POSIX 正则是**最左最长**匹配，不是 PCRE 的回溯语义。它没有 `*?`、`+?` 这样的惰性量词。想让 `.*` 不要吃太多，通常要用否定字符类来限制范围：

```shell
printf 'a "x" b "y"\n' | sed -E 's/.*"([^"]*)".*/\1/'
```

输出：

```shell
y
```

因为 `.*` 会尽可能多地匹配，前面的 `.*` 吃到了最后一个引号之前。想取第一个引号里的内容，要把前缀限制成“不含引号的字符”：

```shell
printf 'a "x" b "y"\n' | sed -E 's/^[^"]*"([^"]*)".*/\1/'
```

输出：

```shell
x
```

这是日志和配置提取里最重要的技巧之一：**用 `[^...]` 划定边界，而不是指望惰性量词**。

### 锚点与单词边界

`^` 和 `$` 分别匹配模式空间的开头和结尾：

```shell
sed -n '/^#/p' examples/data/hosts.txt
```

只打印以 `#` 开头的行。注意 `^` 在方括号里表示取反，不是锚点；`[^#]` 是“不是 `#` 的任意字符”。

GNU sed 支持单词边界：

```shell
printf 'dev devops develop\n' | sed -n 's/\bdev\b/X/gp'
```

输出：

```shell
X devops develop
```

`\b` 匹配单词边界，`\<` 匹配单词开头，`\>` 匹配单词结尾。它们都是 **GNU** 扩展；可移植脚本里不要假设 BSD sed 支持。

`^` 和 `$` 默认只匹配整个模式空间的两端。模式空间里如果有 `N` 拼进来的换行，`^` 不会匹配换行后的位置，除非加上 `M` flag：

```shell
printf 'a\nb\n' | sed 'N;s/^/X/Mg'
```

输出：

```shell
Xa
Xb
```

不加 `M` 时只会在整个模式空间开头加一次：

```shell
printf 'a\nb\n' | sed 'N;s/^/X/g'
```

输出：

```shell
Xa
b
```

### 分组、交替与反向引用

BRE 的分组写成 `\(...\)`，ERE 写成 `(...)`。分组有两个用途：把量词作用到一组字符上，以及捕获内容供替换引用。

交替在 ERE 里是 `|`：

```shell
printf 'cat\ndog\n' | sed -nE '/cat|dog/p'
```

输出：

```shell
cat
dog
```

GNU BRE 也支持 `\|`：

```shell
printf 'cat\ndog\n' | sed -n '/cat\|dog/p'
```

反向引用用 `\1`、`\2` 等。它既可以用在替换文本里，也可以用在正则本身：

```shell
printf 'abab\n' | sed -E 's/(ab)\1/X/'
```

输出：

```shell
X
```

`(ab)\1` 匹配连续两次 `ab`。ERE 里的反向引用不是 POSIX 要求的行为，GNU sed 支持，但换到其他实现可能失效。需要可移植时，把反向引用限制在 BRE 的 `\(...\)\1` 写法里。

### 常见正则写法

从日志里提取状态码和路径：

```shell
sed -nE 's/.*"(GET|POST|DELETE) ([^ ]+) HTTP[^"]*" ([0-9]{3}) .*/\3 \2/p' examples/data/access.log
```

输出：

```shell
200 /index.html
401 /api/login
200 /assets/app.js
404 /missing
500 /api/orders?page=2
204 /api/orders/42
502 /api/orders?page=3
304 /favicon.ico
403 /admin
200 /index.html
```

这里的 `[^ ]+` 表示“一个或多个非空格字符”，用来限定 URL(Uniform Resource Locator) 的结束位置。`[^"]*` 用来跨过 HTTP 版本后面的引号内容，不会越过下一个引号。

筛选 5xx 状态：

```shell
sed -nE '/" 5[0-9]{2} /p' examples/data/access.log
```

BRE 写法是：

```shell
sed -n '/" 5[0-9]\{2\} /p' examples/data/access.log
```

匹配 IPv4 形状：

```shell
sed -nE '/^[0-9]{1,3}(\.[0-9]{1,3}){3} /p' examples/data/access.log
```

输出会包含所有形如 `a.b.c.d` 的行。这个正则只验证“每段一到三位数字”，不验证每段是否在 0 到 255 之间；`999.999.999.999` 也会通过。正则匹配形状，不等于业务校验。

### GNU 扩展与可移植性

GNU sed 增加了不少正则扩展：

- `\+`、`\?`、`\|`：BRE 里的量词和交替。
- `\w`、`\W`、`\s`、`\S`：单词字符和空白字符类。
- `\b`、`\B`、`\<`、`\>`：单词边界。
- `\U`、`\L`、`\u`、`\l`、`\E`：替换文本里的大小写转换。
- `M` flag：让 `^`/`$` 匹配内嵌换行。
- `\xHH` 等转义：不同版本支持程度不同，使用前先测试。

这些写法在 GNU sed 上很方便，但 BSD/macOS 的 sed 不一定支持。写跨平台脚本时，优先使用 POSIX 子集：

- 分组用 `\(...\)`。
- 量词用 `\{m,n\}`。
- 不用 `\+`、`\?`、`\|`，改用多个 `-e` 或更简单的匹配。
- 不用 `\w`、`\s`、`\b`，改用 `[[:alnum:]_]`、`[[:space:]]`，或者用 `[[:<:]]`/`[[:>:]]` 这类实现相关写法前先确认。
- 不用 `\U` 等大小写转换，改用 `tr` 或 awk。

最稳妥的跨平台策略是：脚本里显式调用 `gsed`，并在文档里写明依赖 GNU sed。

### locale 与多字节字符

正则的“字符”到底是什么，取决于 locale。对比下面两条命令。`C.UTF-8` 是很多 Linux 和 Git Bash 环境提供的 UTF-8 locale；如果你的系统没有这个名字，先运行 `locale -a`，换成一个可用的 UTF-8 locale。

```shell
LC_ALL=C.UTF-8 sed 's/./X/g' examples/data/unicode.txt
LC_ALL=C sed 's/./X/g' examples/data/unicode.txt
```

在 UTF-8 locale 下，`.` 匹配一个字符，三行分别被替换成 10、8、8 个 `X`。在 `C` locale 下，`.` 按字节匹配，三行都变成 24 个 `X`，因为一个汉字通常占三个字节，而每行按字节计算都是 24 字节。

字符类也受 locale 影响：

```shell
printf '中文abc123\n' | LC_ALL=C.UTF-8 sed 's/[[:alpha:]]/X/g'
```

在 UTF-8 locale 下，中文也会被算作字母，输出 `XXXXX123`；在 `C` locale 下只匹配 ASCII 字母，输出 `中文XXX123`。后者可以这样复现：

```shell
printf '中文abc123\n' | LC_ALL=C sed 's/[[:alpha:]]/X/g'
```

这不是 sed 的“bug”，而是 locale 的定义。写处理中文的脚本时：

- 明确设置并记录 locale，例如 `export LC_ALL=C.UTF-8`，并确认目标机器有这个 locale。
- 不要用 `.` 去数“看起来像几个字”的字符；它按字符或字节计数，不按 grapheme cluster。
- 需要严格的字节级处理时，显式用 `LC_ALL=C`，并接受多字节字符被拆开的风险。
- 需要 Unicode 属性、字素簇或复杂大小写转换时，换用 Python、Perl 或 ICU 相关工具。

### 常见错误

| 错误 | 实际行为 | 修正 |
| --- | --- | --- |
| 用 `\d` 匹配数字 | GNU sed 不识别 `\d`，通常按字面 `d` 处理 | 用 `[[:digit:]]` 或 `[0-9]` |
| 在 BRE 里写 `a+` | `+` 是普通字符，只匹配 `a+` | 写 `a\+` 或加 `-E` |
| 在 BRE 里直接用括号和竖线做交替 | 括号和竖线都是普通字符，不会产生交替 | 用 BRE 的 <code>\(cat&#124;dog\)</code>，或加 `-E` |
| 用 `.*` 提取引号内容 | `.*` 贪婪，可能越过第一个引号 | 用 `[^"]*` 限定 |
| 用 `[a-z]` 匹配所有字母 | 受 locale 影响，可能不含某些字母 | 用 `[[:lower:]]` 并确认 locale |
| 以为 `^` 在方括号里是锚点 | `[^abc]` 是取反 | 锚点写在方括号外 |
| 在 ERE 里用 `\1` 做可移植脚本 | POSIX ERE 不要求支持反向引用 | 用 BRE，或确认目标实现 |
| 用 `\b` 做跨平台脚本 | BSD sed 不一定支持 | 用 GNU sed，或改用字符类边界 |

### 练习

- 用 BRE 和 ERE 各写一条命令，把 `2025-10-10` 改成 `10/10/2025`。
- 从 `examples/data/access.log` 中提取所有状态码为 404 或 500 的请求方法、路径和状态码。
- 匹配 `examples/data/hosts.txt` 中所有以 `10.` 开头的 IPv4 地址，只打印地址本身。
- 解释为什么 `printf 'a "x" b "y"\n' | sed -E 's/.*"([^"]*)".*/\1/'` 输出 `y` 而不是 `x`，并改成输出 `x`。
- 用 `LC_ALL=C` 和 UTF-8 locale 分别运行 `sed 's/./X/g' examples/data/unicode.txt`，比较输出长度。

<details>
<summary>参考答案</summary>

日期改写：

```shell
printf '2025-10-10\n' | sed 's/\([0-9]\{4\}\)-\([0-9]\{2\}\)-\([0-9]\{2\}\)/\3\/\2\/\1/'
printf '2025-10-10\n' | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'
```

替换文本里的 `/` 需要转义，或者换分隔符：

```shell
printf '2025-10-10\n' | sed -E 's#([0-9]{4})-([0-9]{2})-([0-9]{2})#\3/\2/\1#'
```

提取 404 或 500：

```shell
sed -nE 's/.*"(GET|POST|DELETE) ([^ ]+) HTTP[^"]*" (404|500) .*/\1 \3 \2/p' examples/data/access.log
```

只打印以 `10.` 开头的地址：

```shell
sed -nE 's/^(10\.[0-9.]+) .*/\1/p' examples/data/hosts.txt
```

`.*` 会尽量往后吃，`.*"` 于是吃到了最后一个引号前；`[^"]*` 只能停在引号处。要取第一个引号内容，用 `^[^"]*"([^"]*)"` 把前缀限制为“到第一个引号为止”。

locale 对比：UTF-8 下按字符替换，`C` locale 下按字节替换，后者输出的 `X` 更多。

</details>

下一篇：[常用编辑命令](editing-commands.md)。
