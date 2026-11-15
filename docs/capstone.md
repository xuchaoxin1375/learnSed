## 综合练习

这一篇不引入新语法，而是把前面的能力组合起来。建议先独立完成，再展开答案。所有任务都在仓库根目录执行，使用 `examples/data/` 里的虚构数据。

完成后运行 `bash scripts/verify.sh` 做整体检查。

### 整理主机清单

从 [hosts.txt](../examples/data/hosts.txt) 中提取所有 `dev.local` 主机：

- 删除注释行和空行。
- 把连续空白压成一个空格。
- 去掉行首多余空格。
- 在每行前输出原始行号，格式为“行号 + 制表符 + 内容”。

期望输出的前两行类似：

```shell
7	10.0.0.5 api.dev.local
8	10.0.0.6 db.dev.local # primary database
```

提示：可以用 `sed -n` 加地址、`=`、`s`，也可以先用一个 sed 过滤，再用另一个 sed 合并行号。

### 修改配置

复制 [config.ini](../examples/data/config.ini) 到 `tmp/config.ini`，完成：

- 只把 `[server]` 段的 `port` 改成 `9090`。
- 保留 `-i.bak` 备份。
- 用 `diff -u` 证明只改了这一行。
- 输出修改后的 server 段内容，不包含 section 标题和空行。

期望 `[server]` 段变成：

```ini
host = 127.0.0.1
port = 9090
debug = true
```

### 日志摘要

对 [access.log](../examples/data/access.log)：

- 提取所有 5xx 请求的完整行。
- 统计各状态码出现次数。
- 把客户端 IPv4 的最后一段替换成 `xxx`，只显示前三行。
- 统计每个请求路径出现的次数，按次数从高到低排序。

期望 5xx 有两行，状态码统计里 `200` 出现 3 次。

### 整理多行文本

对 [continuation.conf](../examples/data/continuation.conf) 和 [paragraphs.txt](../examples/data/paragraphs.txt)：

- 把反斜杠续行合并成一行，去掉续行前的缩进。
- 把每个段落合并成一行。
- 解释这两个任务分别用了哪些跨行命令。

### 渲染模板

对 [template.txt](../examples/data/template.txt)：

- 用 shell 变量替换 `{{NAME}}`、`{{ORDER_ID}}`、`{{EMAIL}}`。
- 变量值 `NAME` 设为 `A/B`，说明为什么用 `|` 做分隔符。
- 如果把 `NAME` 设为 `A&B`，输出会变成什么？为什么？

### 处理 CSV

CSV(Comma-Separated Values, 逗号分隔值) 是常见的表格文本格式。对 [users.csv](../examples/data/users.csv)：

- 把逗号换成制表符。
- 提取姓名列，跳过表头。
- 交换前两列。
- 说明这些命令在什么 CSV 上会失效。

### 写一个 sed 脚本

创建一个 `clean.sed`，完成：

- 删除整行注释。
- 删除空行。
- 把连续空白压成一个空格。
- 去掉行首行尾空白。

用 `-f` 处理 `examples/data/hosts.txt`，并说明为什么脚本里用 `[[:space:]]\+` 而不是 `+`。

### 判断工具

下面任务分别更适合 sed、awk、jq 还是 Python？说明理由。

- 把配置文件里的 `localhost` 全部换成 `127.0.0.1`。
- 计算日志里每个状态码的占比。
- 从嵌套 JSON 里取出所有用户的邮箱。
- 解析带引号和逗号的 CSV。
- 给文件的每一行加行号。

<details>
<summary>参考答案</summary>

**整理主机清单**：

```shell
sed -n '/dev\.local/{=;s/[[:space:]]\+/ /g;s/^[[:space:]]*//;p}' examples/data/hosts.txt
```

输出：

```shell
7
10.0.0.5 api.dev.local
8
10.0.0.6 db.dev.local # primary database
9
10.0.0.7 cache.dev.local
```

如果要把行号和内容放在同一行，可以再接：

```shell
sed -n '/dev\.local/{=;s/[[:space:]]\+/ /g;s/^[[:space:]]*//;p}' examples/data/hosts.txt | sed 'N;s/\n/\t/'
```

输出：

```shell
7	10.0.0.5 api.dev.local
8	10.0.0.6 db.dev.local # primary database
9	10.0.0.7 cache.dev.local
```

**修改配置**：

```shell
mkdir -p tmp
cp examples/data/config.ini tmp/config.ini
sed -i.bak '/^\[server\]/,/^\[client\]/{s/^port = .*/port = 9090/}' tmp/config.ini
diff -u examples/data/config.ini tmp/config.ini
sed -n '/^\[server\]/,/^\[client\]/{/^\[/d;/^$/d;p}' tmp/config.ini
```

`diff -u` 只应报告 `port = 8080` 变成 `port = 9090`。最后一条输出：

```ini
host = 127.0.0.1
port = 9090
debug = true
```

**日志摘要**：

5xx：

```shell
sed -nE '/" 5[0-9]{2} /p' examples/data/access.log
```

状态码统计：

```shell
sed -nE 's/.*" ([0-9]{3}) [0-9]+ .*/\1/p' examples/data/access.log | sort | uniq -c
```

脱敏并显示前三行：

```shell
sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.)[0-9]+/\1xxx/' examples/data/access.log | sed -n '1,3p'
```

路径统计：

```shell
sed -nE 's/.*"(GET|POST|DELETE) ([^ ]+) HTTP[^"]*" [0-9]{3} .*/\2/p' examples/data/access.log | sort | uniq -c | sort -rn
```

**整理多行文本**：

合并续行：

```shell
sed -e :a -e '/\\$/N' -e 's/[[:space:]]*\\\n[[:space:]]*/ /' -e 'ta' examples/data/continuation.conf
```

合并段落：

```shell
sed -n '/./{H;$!d};x;s/^\n//;s/\n/ /g;p' examples/data/paragraphs.txt
```

续行用了 `N` 把下一行追加到模式空间，`t` 循环处理连续多行；段落用了保持空间 `H` 累积、`x` 取回、`d` 跳过中间输出。

**渲染模板**：

```shell
NAME='A/B'
ORDER_ID=42
EMAIL=alice@example.com
sed -e "s|{{NAME}}|$NAME|" -e "s/{{ORDER_ID}}/$ORDER_ID/" -e "s/{{EMAIL}}/$EMAIL/" examples/data/template.txt
```

用 `|` 是因为值里含 `/`，继续用 `/` 会破坏 `s` 的分隔符。

如果 `NAME='A&B'`：

```shell
NAME='A&B'
sed "s|{{NAME}}|$NAME|" examples/data/template.txt
```

输出第一行是 `Hello, A{{NAME}}B!`。替换文本里的 `&` 被展开成匹配到的 `{{NAME}}`，不是字面量 `&`。需要字面量时用 Python 的 `str.replace` 或先转义。

**处理 CSV**：

```shell
sed 's/,/\t/g' examples/data/users.csv
sed -nE '2,$s/^([^,]*),([^,]*),.*/\2/p' examples/data/users.csv
sed -E 's/^([^,]+),([^,]+),/\2,\1,/' examples/data/users.csv
```

这些命令假设字段里没有逗号、没有引号。带引号的 CSV 需要真正的 CSV 解析器。

**写一个 sed 脚本**：

`clean.sed`：

```sed
/^[[:space:]]*#/d
/^[[:space:]]*$/d
s/[[:space:]]\+/ /g
s/^[[:space:]]*//
s/[[:space:]]*$//
```

运行：

```shell
sed -f clean.sed examples/data/hosts.txt
```

BRE 里的 `+` 是普通字符，`\+` 才是“一次或多次”；GNU sed 支持 `\+`，POSIX 脚本可以写成 `\{1,\}`。

**判断工具**：

- 批量替换固定字符串：sed 最直接。
- 计算状态码占比：awk 更合适，能按字段聚合和计算。
- 嵌套 JSON 取邮箱：jq 或 Python 的 JSON 库。
- 带引号的 CSV：Python 的 `csv` 模块。
- 加行号：sed 可以，`nl` 或 awk 也可以；单文件快速处理用 sed 足够。

</details>

回到 [README](../README.md) 查看学习路径，或打开 [速查表](cheatsheet.md) 复习。
