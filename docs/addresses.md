## 地址与范围

上一篇的脚本默认作用于每一行。真实任务里，我们通常只想处理其中一部分：某个 section、某个时间段、从匹配行到另一个匹配行、除注释以外的所有行。**地址**(address)就是 sed 用来筛选记录的前缀。

地址写在命令前面。没有地址时，命令对每条记录执行；有地址时，只有地址匹配的记录才执行。地址只决定“命令是否运行”，不会改变命令本身的行为。

### 地址的写法

| 写法 | 含义 | 备注 |
| --- | --- | --- |
| `n` | 第 `n` 条输入记录 | 行号从 1 开始；多个文件默认连续编号 |
| `$` | 最后一条记录 | 加 `-s` 时是每个文件的最后一行 |
| `/regex/` | 匹配正则的行 | 空正则 `//` 复用上一次的正则 |
| `\cREGEXc` | 用自定义分隔符 `c` 包围正则 | POSIX 写法，适合正则里含 `/` |
| `first~step` | 从第 `first` 行开始，每隔 `step` 行 | **GNU**；`1~2` 是奇数行，`0~2` 是偶数行 |
| `addr1,addr2` | 从 `addr1` 匹配开始，到 `addr2` 匹配结束 | 两端都包含 |
| `addr,+N` | 从 `addr` 匹配行开始，再往后 `N` 行 | **GNU**；到 EOF 自动停止 |
| `addr,~N` | 从 `addr` 匹配行开始，到下一个行号为 `N` 倍数的行 | **GNU** |
| `0,/regex/` | 从第 1 行之前开始，到第一次匹配 `regex` 的行 | **GNU**；允许结束正则匹配第 1 行 |

`0` 不能单独作为行号使用，`sed -n '0p'` 会报错。它只在 `0,/regex/` 这种范围写法里有特殊含义。

### 单地址

行号是最直接的形式：

```shell
sed -n '1,3p' examples/data/hosts.txt
```

输出：

```shell
# /etc/hosts sample (all addresses are documentation examples)

127.0.0.1       localhost
```

注意第 1 行是注释，第 2 行是空行，第 3 行才是第一条主机记录。行号按输入记录计数，不会跳过空行或注释。

`$` 匹配最后一行：

```shell
sed -n '$p' examples/data/hosts.txt
```

输出：

```shell
10.1.0.6        db.prod.local
```

正则地址匹配包含该模式的行：

```shell
sed -n '/dev\.local/p' examples/data/hosts.txt
```

输出：

```shell
10.0.0.5        api.dev.local
10.0.0.6        db.dev.local      # primary database
10.0.0.7        cache.dev.local
```

这里的 `\.` 是在正则里转义点号。如果写成 `/dev.local/`，点号会匹配任意字符，可能命中 `devXlocal`。正则细节会在下一篇展开，这里先记住：**地址里的正则和 `s` 命令里的正则是同一套语法**。

### 范围

范围由两个地址组成，用逗号分隔：

```shell
sed -n '/development/,/production/p' examples/data/hosts.txt
```

输出：

```shell
# development
10.0.0.5        api.dev.local
10.0.0.6        db.dev.local      # primary database
10.0.0.7        cache.dev.local

# production
```

起始行 `# development` 被包含，结束行 `# production` 也被包含。范围是**闭区间**，不是“到结束行之前”。

如果结束正则永远不匹配，范围会一直延伸到文件末尾：

```shell
sed -n '/production/,/does-not-exist/p' examples/data/hosts.txt
```

输出和 `sed -n '/production/,$p'` 一样。写范围时先确认结束模式真的存在，否则很容易把整个文件后半段都打出来。

`addr,+N` 用行数而不是正则来结束范围：

```shell
sed -n '/development/,+2p' examples/data/hosts.txt
```

输出：

```shell
# development
10.0.0.5        api.dev.local
10.0.0.6        db.dev.local      # primary database
```

起始行本身算第一行，再加两行，共三行。`+N` 在到达 EOF 时会提前停止，不会报错。

`addr,~N` 到下一个行号为 `N` 的倍数的行结束：

```shell
sed -n '3,~2p' examples/data/config.ini
```

输出：

```shell
host = 127.0.0.1
port = 8080
```

第 3 行开始，下一个 2 的倍数是第 4 行，所以范围是第 3 到第 4 行。它和 `+1` 在数值上可能相同，但语义不同：`+N` 数的是相对行数，`~N` 找的是绝对行号的倍数。

### 范围结束正则的测试时机

这是 sed 地址里最容易踩的坑：**当 `addr2` 是正则时，它从 `addr1` 匹配行的下一行开始测试，不会在起始行本身上测试**。

看一个只有一行的输入：

```shell
printf 'aaa\nbbb\n' | sed -n '/aaa/,/aaa/p'
```

输出：

```shell
aaa
bbb
```

第 1 行匹配 `aaa`，范围开始；结束正则从第 2 行开始找，找不到，于是一直到 EOF。很多人的直觉是“同一行既是开始又是结束”，但 sed 不是这样工作的。

连续两行都匹配时，结束正则会命中第二行：

```shell
printf 'start\nstart\nend\n' | sed -n '/start/,/start/p'
```

输出：

```shell
start
start
```

第 1 行开始范围，第 2 行匹配结束正则，范围在第 2 行结束。

如果确实希望结束正则能匹配起始行，用 **GNU** 的 `0,/regex/`：

```shell
printf 'a=1\na=2\na=3\n' | sed '0,/^a=/s/=.*/=0/'
```

输出：

```shell
a=0
a=2
a=3
```

`0,/^a=/` 从第 1 行之前开始，结束正则可以从第 1 行开始测试，所以只处理了第一行。作为对比，普通的 `/^a=/,/^a=/` 会在第 1 行开始，在第 2 行结束，然后第 3 行又开启新一轮范围，最终三行都被替换：

```shell
printf 'a=1\na=2\na=3\n' | sed '/^a=/,/^a=/s/=.*/=0/'
```

输出：

```shell
a=0
a=0
a=0
```

范围可以重复匹配。匹配次数为奇数时，最后一段范围可能一直延伸到 EOF。看到“范围输出比预期长”时，先数一数起始模式出现了几次。

### 范围在多个文件之间

默认情况下，多个文件被视为一个连续的输入流：行号继续累加，范围可以跨文件，`$` 只匹配整个输入的最后一行。

```shell
printf 'a\nb\n' > /tmp/one.txt
printf 'c\nd\n' > /tmp/two.txt
sed -n '$p' /tmp/one.txt /tmp/two.txt
```

输出：

```shell
d
```

加上 `-s` 或 `--separate` 后，每个文件单独处理：行号重置，`$` 是每个文件的最后一行，范围不会跨文件。这是 **GNU** 扩展：

```shell
sed -n -s '$p' /tmp/one.txt /tmp/two.txt
```

输出：

```shell
b
d
```

需要按文件分别统计、分别改配置时，`-s` 很重要。否则第二个文件会继承第一个文件的行号和范围状态。

### 否定与命令块

地址后面加 `!` 表示“除了这些行”。例如打印所有非注释行：

```shell
sed -n '/^#/!p' examples/data/hosts.txt
```

空行也会被打印，因为空行不以 `#` 开头。如果连空行也不要，可以叠加一个地址：

```shell
sed -n '/^#/!{/^$/!p}' examples/data/hosts.txt
```

花括号把多条命令绑定到同一个地址。下面从 `[server]` 到 `[client]` 的范围里删除 section 标题和空行，只打印配置内容：

```shell
sed -n '/^\[server\]/,/^\[client\]/{/^\[/d;/^$/d;p}' examples/data/config.ini
```

输出：

```shell
host = 127.0.0.1
port = 8080
debug = true
```

`[client]` 是范围的结束行，也被包含在范围内；`/^\[/d` 把它和 `[server]` 一起删掉。如果不删除它，输出会多一行 `[client]`。

命令块里的每条命令都继承外层地址。块可以嵌套，但嵌套太深会迅速变得难读。遇到这种情况，先考虑用多个 `-e` 或拆成脚本文件。

### 删除与打印的组合

`d` 和 `p` 对范围的反应不同：

- `sed '/^#/d'` 删除注释行，其余行默认打印。
- `sed -n '/^#/p'` 只打印注释行。
- `sed '/^#/!d'` 删除非注释行，等价于只保留注释行。

最后一种写法利用 `!` 和 `d`：所有不匹配 `^#` 的行被删除，剩下的注释行走默认打印。它比 `-n` 加 `p` 少一个开关，但在复杂脚本里不如显式 `p` 直观。

### 练习

- 打印 `examples/data/poem.txt` 的第 2 到第 3 行。
- 打印 `examples/data/hosts.txt` 中从 `# development` 到其后第一个空行的内容。
- 只打印 `examples/data/config.ini` 的 `[server]` 段内容，不包含 section 标题和空行。
- 把 `examples/data/config.ini` 中 `[server]` 段的 `port` 改成 `9090`，只输出修改后的行，不修改文件。
- 解释为什么 `printf 'a\n' | sed -n '/a/,/a/p'` 会输出 `a`，尽管开始和结束是同一个模式。

<details>
<summary>参考答案</summary>

打印第 2 到第 3 行：

```shell
sed -n '2,3p' examples/data/poem.txt
```

从开发环境标题到第一个空行：

```shell
sed -n '/# development/,/^$/p' examples/data/hosts.txt
```

这段范围包含结尾的空行。如果想排除空行，在命令块里加 `/^$/d`。

打印 `[server]` 段内容：

```shell
sed -n '/^\[server\]/,/^\[client\]/{/^\[/d;/^$/d;p}' examples/data/config.ini
```

只改 server 段的 port 并输出：

```shell
sed -n '/^\[server\]/,/^\[client\]/{/^port = /s/=.*/= 9090/p}' examples/data/config.ini
```

输出只有一行 `port = 9090`。范围包含 `[client]`，但 `port` 只在 server 段出现，所以不会误改 client 的端口。

最后一条：`addr2` 是正则时，sed 从起始行的下一行开始测试结束条件。输入只有一行，没有下一行可测试，范围就一直延伸到 EOF，于是 `a` 被打印。

</details>

下一篇：[替换命令 s](substitute.md)。
