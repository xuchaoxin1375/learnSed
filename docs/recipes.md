## 实战案例

这一篇把前面的概念放进完整任务：清理配置、精确修改 section、分析日志、批量替换、渲染模板、整理多行文本、提取配置块和处理简单 CSV。

每个案例都包含目标、数据、命令、输出和验证方式。命令默认在仓库根目录执行；需要写文件的案例使用 `tmp/` 目录，结束后可以整体删除。

### 清理配置文件

**目标**：去掉整行注释和空行，去掉首尾空白，把 `key = value` 统一成 `key=value`。

数据是 [dirty.txt](../examples/data/dirty.txt)：

```ini
# sample config
server.host = 10.0.0.5
server.port = 8080

# debug
debug = true
timeout = 30   
```

最后一行 `timeout = 30` 后面有尾随空格。

命令：

```shell
sed -e 's/^[[:space:]]*//' \
    -e 's/[[:space:]]*$//' \
    -e 's/[[:space:]]*=[[:space:]]*/=/' \
    -e '/^#/d' \
    -e '/^$/d' \
    examples/data/dirty.txt
```

输出：

```shell
server.host=10.0.0.5
server.port=8080
debug=true
timeout=30
```

命令顺序不是随意的：

- 先去掉行首和行尾空白，后面的 `^#` 和 `^$` 才能准确匹配。
- `s/[[:space:]]*=[[:space:]]*/=/` 把等号两侧的空白压掉；它只处理第一个等号。
- 最后删除注释行和空行，避免在删除前做无意义的替换。

这个脚本只删除**整行注释**。如果配置里有 `port=8080 # comment` 这样的行尾注释，需要额外的 `s/[[:space:]]*#.*$//`，但这会把值里的 `#` 也当成注释。是否安全取决于配置格式，不要直接套用。

### 只改一个 section 的端口

**目标**：只把 `[server]` 段的 `port` 改成 `9090`，不动 `[client]` 的 `443`。

数据是 [config.ini](../examples/data/config.ini)。先复制到临时目录：

```shell
mkdir -p tmp
cp examples/data/config.ini tmp/config.ini
```

预览命令：

```shell
sed -n '/^\[server\]/,/^\[client\]/{/^port = /s/=.*/= 9090/p}' tmp/config.ini
```

输出：

```shell
port = 9090
```

确认后写回，并保留备份：

```shell
sed -i.bak '/^\[server\]/,/^\[client\]/{s/^port = .*/port = 9090/}' tmp/config.ini
```

检查修改后的文件：

```shell
sed -n '/^port = /p' tmp/config.ini
```

输出：

```shell
port = 9090
port = 443
```

检查备份：

```shell
sed -n '/^port = /p' tmp/config.ini.bak
```

输出：

```shell
port = 8080
port = 443
```

修改后的文件里，`[server]` 是 `9090`，`[client]` 仍是 `443`；备份里是原始的两个端口。也可以运行 `diff -u examples/data/config.ini tmp/config.ini`，预期只看到 `8080` 变成 `9090`。

范围 `/^\[server\]/,/^\[client\]/` 包含了 `[client]` 这一行，但替换只匹配 `port`，所以不会误改 client 的端口。如果 section 是文件最后一段，结束模式不存在，范围会延伸到 EOF；这正好是想要的效果，但写通用脚本时要意识到这个边界。

### 分析访问日志

**目标**：从 [access.log](../examples/data/access.log) 中提取 5xx 请求、统计状态码、脱敏客户端 IP。

提取 5xx 行：

```shell
sed -nE '/" 5[0-9]{2} /p' examples/data/access.log
```

输出：

```shell
198.51.100.7 - - [10/Oct/2025:13:56:31 +0800] "GET /api/orders?page=2 HTTP/1.1" 500 87 "-" "curl/8.5.0"
192.0.2.44 - - [10/Oct/2025:13:57:12 +0800] "GET /api/orders?page=3 HTTP/1.1" 502 91 "-" "Mozilla/5.0"
```

统计状态码，需要把提取结果交给 `sort` 和 `uniq`：

```shell
sed -nE 's/.*" ([0-9]{3}) [0-9]+ .*/\1/p' examples/data/access.log | sort | uniq -c
```

输出：

```shell
      3 200
      1 204
      1 304
      1 401
      1 403
      1 404
      1 500
      1 502
```

sed 只负责把状态码变成一行一个；计数是 `sort | uniq -c` 完成的。把多个工具串起来，比用一个巨大的 sed 脚本可靠。

把 IPv4 的最后一段替换成 `xxx`：

```shell
sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+\.)[0-9]+/\1xxx/' examples/data/access.log | sed -n '1,3p'
```

输出前三行：

```shell
203.0.113.xxx - - [10/Oct/2025:13:55:36 +0800] "GET /index.html HTTP/1.1" 200 1043 "-" "Mozilla/5.0"
198.51.100.xxx - - [10/Oct/2025:13:55:40 +0800] "POST /api/login HTTP/1.1" 401 512 "-" "curl/8.5.0"
203.0.113.xxx - - [10/Oct/2025:13:56:02 +0800] "GET /assets/app.js HTTP/1.1" 200 87231 "https://example.com/" "Mozilla/5.0"
```

去掉最后的 `sed -n '1,3p'` 会处理全部十行。这里的正则只处理“行首是 IPv4”的格式；如果日志前面有代理头、时间戳或其他字段，要调整锚点。

日志是半结构化数据，字段里可能有空格和引号。需要按字段统计、求和、排序时，awk 或专用日志工具更合适。sed 擅长“按行筛选和改写”，不擅长“理解字段”。

### 批量替换项目文本

**目标**：把 `tmp/demo` 下所有 Markdown 文件里的 `old-name` 改成 `new-name`，并保留备份。

先创建演示项目：

```shell
mkdir -p tmp/demo/docs
printf 'Project: old-name\nPath: /srv/old-name\n' > tmp/demo/docs/a.md
printf 'old-name appears here too.\n' > tmp/demo/docs/b.md
```

预览命中文件：

```shell
find tmp/demo -name '*.md' -exec grep -l 'old-name' {} +
```

输出：

```shell
tmp/demo/docs/a.md
tmp/demo/docs/b.md
```

批量替换：

```shell
find tmp/demo -name '*.md' -exec sed -i.bak 's/old-name/new-name/g' {} +
```

检查结果：

```shell
find tmp/demo -name '*.md' -exec grep -H 'new-name' {} +
```

输出：

```shell
tmp/demo/docs/a.md:Project: new-name
tmp/demo/docs/a.md:Path: /srv/new-name
tmp/demo/docs/b.md:new-name appears here too.
```

备份文件仍然存在：

```shell
find tmp/demo -name '*.bak' | sort
```

输出：

```shell
tmp/demo/docs/a.md.bak
tmp/demo/docs/b.md.bak
```

确认无误后清理演示目录：

```shell
rm -rf tmp
```

关键点：

- `-exec ... +` 把多个文件一次传给 sed；`-i` 隐含 `-s`，每个文件独立处理。
- `-i.bak` 为每个文件生成 `.bak`，可用于回滚或 `diff`。
- 正式项目里先跑 `git diff` 或 `grep` 预览，再决定是否替换。
- 不要对二进制文件、锁文件、构建产物使用文本替换；`find` 的条件要收窄。

### 渲染模板

**目标**：把 [template.txt](../examples/data/template.txt) 里的占位符替换成变量值。

```shell
NAME=Alice
ORDER_ID=42
EMAIL=alice@example.com
sed -e "s/{{NAME}}/$NAME/" \
    -e "s/{{ORDER_ID}}/$ORDER_ID/" \
    -e "s/{{EMAIL}}/$EMAIL/" \
    examples/data/template.txt
```

输出：

```shell
Hello, Alice!
Order 42 is ready.
Contact: alice@example.com
```

变量赋值要单独成行。把 `NAME=Alice` 写在 `sed` 前面同一行，shell 会在启动 sed 之前展开双引号，此时变量还没有值。

如果变量值里含 `/`，用 `|` 做分隔符：

```shell
NAME='A/B'
sed "s|{{NAME}}|$NAME|" examples/data/template.txt
```

输出：

```shell
Hello, A/B!
Order {{ORDER_ID}} is ready.
Contact: {{EMAIL}}
```

如果值里含 `&`，替换结果会被 sed 改写：

```shell
printf 'x\n' | sed 's|x|A&B|'
```

输出：

```shell
AxB
```

`&` 被展开成匹配到的 `x`，所以不是字面量 `A&B`。处理用户输入、文件名或 HTML 片段时，不要直接把值拼进 sed 脚本。需要可靠的字面量替换时，用 Python 的 `str.replace`，或者先对值做 sed 转义。

### 整理续行与段落

**目标**：把 [continuation.conf](../examples/data/continuation.conf) 的反斜杠续行合并，把 [paragraphs.txt](../examples/data/paragraphs.txt) 的每个段落合并成一行。

合并续行：

```shell
sed -e :a \
    -e '/\\$/N' \
    -e 's/[[:space:]]*\\\n[[:space:]]*/ /' \
    -e 'ta' \
    examples/data/continuation.conf
```

输出：

```shell
DATABASE_URL=postgres://db:5432/app ?sslmode=require
CACHE_URL=redis://cache:6379/0
```

合并段落：

```shell
sed -n '/./{H;$!d};x;s/^\n//;s/\n/ /g;p' examples/data/paragraphs.txt
```

输出：

```shell
Sed reads input line by line. It keeps the current line in the pattern space.
Multiple lines can be joined with N. The hold space survives across cycles.
This is the last paragraph.
```

这两个脚本都依赖上一章的 `N`、`H`、`t` 和保持空间。先用小文件验证，再处理真实配置；真实文件可能有空行、注释和 Windows 换行。

### 提取配置块

**目标**：从 [block.txt](../examples/data/block.txt) 中提取起止标记之间的内容。

包含标记：

```shell
sed -n '/^# BEGIN app settings$/,/^# END app settings$/p' examples/data/block.txt
```

输出：

```shell
# BEGIN app settings
host = 127.0.0.1
port = 8080
# END app settings
```

不包含标记：

```shell
sed -n '/^# BEGIN app settings$/,/^# END app settings$/{/^# BEGIN/d;/^# END/d;p}' examples/data/block.txt
```

输出：

```shell
host = 127.0.0.1
port = 8080
```

如果结束标记不存在，范围会一直到 EOF。这是 sed 地址的正常行为，不是错误；提取前先确认标记成对出现，或者在脚本里加检查。

### 处理简单 CSV

**目标**：处理一份简单 CSV(Comma-Separated Values, 逗号分隔值)：把 [users.csv](../examples/data/users.csv) 的逗号换成制表符、提取第二列、交换前两列。

逗号换制表符：

```shell
sed 's/,/\t/g' examples/data/users.csv
```

输出：

```shell
id	name	email	role
1	Alice	alice@example.com	admin
2	Bob	bob@example.com	user
3	Carol	carol@example.com	user
4	Dave	dave@example.com	viewer
```

提取第二列：

```shell
sed -nE 's/^([^,]*),([^,]*),.*/\2/p' examples/data/users.csv
```

输出：

```shell
name
Alice
Bob
Carol
Dave
```

交换前两列：

```shell
sed -E 's/^([^,]+),([^,]+),/\2,\1,/' examples/data/users.csv
```

输出：

```shell
name,id,email,role
Alice,1,alice@example.com,admin
Bob,2,bob@example.com,user
Carol,3,carol@example.com,user
Dave,4,dave@example.com,viewer
```

这些命令只适用于**没有引号、字段内没有逗号**的简单 CSV。下面这种数据会破坏结果：

```csv
id,name,note
1,Alice,"hello, world"
```

`sed 's/,/\t/g'` 会把 `"hello, world"` 里的逗号也换掉，字段数就错了。带引号的 CSV 用 Python 的 `csv` 模块、`awk` 的字段解析或专门的 CSV 工具。

### 验证与清理

案例中创建的 `tmp/` 目录可以整体删除：

```shell
rm -rf tmp
```

运行仓库的自动校验：

```shell
bash scripts/verify.sh
```

它会验证教程中的核心行为，不会改仓库文件。真实项目里，修改文件前先备份、先预览、先在小样本上确认，替换后检查 `git diff` 或 `diff -u`。

### 练习

- 从 `examples/data/hosts.txt` 中提取所有 `dev.local` 主机，去掉多余空白，并在每行前加两个空格。
- 把 `examples/data/config.ini` 的 `[logging]` 段整体替换成一行注释，输出到终端，不修改文件。
- 统计 `examples/data/access.log` 中每个路径出现的次数，按次数从高到低排序。
- 只改 `examples/data/config.ini` 的 `[server]` 段端口，使用 `-i.bak`，并用 `diff -u` 验证。
- 把 `examples/data/users.csv` 的姓名列提取出来，跳过表头。

<details>
<summary>参考答案</summary>

提取 dev 主机并加缩进：

```shell
sed -n '/dev\.local/{s/[[:space:]]\+/ /g;s/^/  /;p}' examples/data/hosts.txt
```

替换 logging 段：

```shell
sed '/^\[logging\]/,$c\# logging disabled' examples/data/config.ini
```

路径计数：

```shell
sed -nE 's/.*"(GET|POST|DELETE) ([^ ]+) HTTP[^"]*" [0-9]{3} .*/\2/p' examples/data/access.log | sort | uniq -c | sort -rn
```

改端口：

```shell
mkdir -p tmp
cp examples/data/config.ini tmp/config.ini
sed -i.bak '/^\[server\]/,/^\[client\]/{s/^port = .*/port = 9090/}' tmp/config.ini
diff -u examples/data/config.ini tmp/config.ini
```

提取姓名并跳过表头：

```shell
sed -nE '2,$s/^([^,]*),([^,]*),.*/\2/p' examples/data/users.csv
```

`2,$` 从第 2 行开始，避开表头。

</details>

下一篇：[排错与常见陷阱](troubleshooting.md)。
