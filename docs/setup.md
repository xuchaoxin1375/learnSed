## 环境与约定

这一篇只做三件事：确认你用的是 GNU sed，认识仓库里的示例数据，跑通第一条命令。sed 的概念和工作模型从下一篇开始。

### 为什么强调 GNU sed

POSIX(Portable Operating System Interface) 定义了一个 sed 的最小公共子集，GNU sed 和 BSD sed 都实现了它，但扩展并不相同。本教程大量使用 GNU 扩展，例如 `0,/re/`、`addr,+N`、`\w`、`\U`、`-z` 和 `--debug`。在 BSD sed 上，这些写法可能报错，也可能产生不同结果。

先看版本：

```shell
sed --version
```

GNU sed 的第一行会包含 `GNU sed` 和版本号，例如 `sed (GNU sed) 4.9`。如果命令报错，或者第一行是 `sed: illegal option -- -`，说明当前 `sed` 不是 GNU 版。

在 macOS 上，可以安装 GNU 版并显式使用 `gsed`：

```shell
brew install gnu-sed
gsed --version
```

Homebrew 通常会把可执行文件装成 `gsed`，避免覆盖系统自带的 `sed`。正文里的命令仍然写 `sed`；在 macOS 上跟做时，把命令开头的 `sed` 换成 `gsed` 即可。也可以临时设置别名，但脚本里显式写 `gsed` 更可靠。

Windows 用户推荐使用 Git Bash 或 WSL。Git Bash 自带 GNU sed；PowerShell 中的 `sed` 可能是别名、Scoop 包或其他移植版，行为不一定与本教程一致。确认方式仍然是 `sed --version`。

Linux 多数发行版已经预装 GNU sed。Debian/Ubuntu 可以用 `sudo apt install sed` 补装，Fedora 用 `sudo dnf install sed`。

### 检查 locale 与编码

本教程的文件是 UTF-8。sed 对多字节字符的处理依赖 locale：

```shell
locale
```

关注 `LC_ALL`、`LC_CTYPE` 和 `LANG`。如果它们为空、为 `C` 或为 `POSIX`，sed 可能把中文按字节处理，`.` 匹配的是单个字节，而不是一个汉字。最可靠的判断是直接做一个最小测试：

```shell
printf '中\n' | sed 's/./X/g'
```

输出 `X` 表示按字符匹配，输出 `XXX` 表示按字节匹配。需要按字符处理时，设置一个 UTF-8 locale，例如：

```shell
export LC_ALL=C.UTF-8
```

不是每个系统都有 `C.UTF-8`。可以先运行 `locale -a` 查看可用名称；macOS 常用 `en_US.UTF-8`，Linux 常用 `C.utf8` 或 `C.UTF-8`。设置后在同一个 shell 会话里继续操作。`bash scripts/check-env.sh` 也会用同样的测试给出提示。

后面的正则章节会用 `examples/data/unicode.txt` 演示字符与字节的差异。涉及中文的示例会注明 locale 前提。

### 示例数据

所有数据都是虚构的，IP 取自 RFC 5737 的文档保留地址段，域名使用 `example.com` 或 `.local`。

| 文件 | 用途 |
| --- | --- |
| [hosts.txt](../examples/data/hosts.txt) | 注释、空行、主机记录，练习地址与范围 |
| [access.log](../examples/data/access.log) | 类 Apache 访问日志，练习正则提取与脱敏 |
| [config.ini](../examples/data/config.ini) | 带 section 的配置，练习段落范围与就地修改 |
| [dirty.txt](../examples/data/dirty.txt) | 多余空格、注释、空行，练习清理 |
| [users.csv](../examples/data/users.csv) | 简单 CSV，练习字段重排与分隔符转换 |
| [poem.txt](../examples/data/poem.txt) | 短文本，练习行选择、反转、编号 |
| [employees.txt](../examples/data/employees.txt) | 含重复名字，练习去重 |
| [paragraphs.txt](../examples/data/paragraphs.txt) | 多段落，练习合并 |
| [continuation.conf](../examples/data/continuation.conf) | 反斜杠续行，练习跨行连接 |
| [block.txt](../examples/data/block.txt) | 带起止标记的配置块 |
| [template.txt](../examples/data/template.txt) | 占位符模板，练习变量替换 |
| [unicode.txt](../examples/data/unicode.txt) | 中文文本，练习 locale 与字符匹配 |

[examples/scripts/clean-hosts.sed](../examples/scripts/clean-hosts.sed) 是一个可以直接用 `-f` 调用的脚本示例。

### 运行方式

所有命令默认在仓库根目录执行。先进入仓库：

```shell
cd /path/to/learnSed
```

后面的命令使用相对路径 `examples/data/...`。如果你的当前目录不同，先回到仓库根目录，或者把路径改成实际位置。

仓库自带两个检查脚本：

```shell
bash scripts/check-env.sh
```

它检查 `sed` 是否存在、是否为 GNU 版、是否支持 `--debug`，以及示例数据是否齐全。检查通过时退出码为 `0`；不是 GNU sed 或数据缺失时退出码为 `1`，并给出提示。UTF-8 匹配能力只作为警告，不改变退出码。

```shell
bash scripts/verify.sh
```

它会在临时目录里运行一组断言，验证教程中的核心行为。脚本不会修改仓库里的文件；失败时会打印期望值与实际值。

### 先跑一条命令

先不修改任何文件，只把结果送到终端：

```shell
sed 's/stream/line/' examples/data/poem.txt
```

预期输出：

```shell
roses are red
violets are blue
sed is a line editor
and so are you
```

这条命令做了三件事：逐行读取文件、在每一行里把第一个 `stream` 换成 `line`、把修改后的行打印出来。文件本身没有变化。

再看内部循环：

```shell
printf 'hello world\n' | sed --debug 's/world/sed/'
```

`--debug` 是 **GNU** 扩展。它会打印 sed 解析出的脚本、当前模式空间、命中的命令和正则寄存器，然后才输出结果。第一次看会觉得吵，但它是理解 sed 行为最直接的工具。下一篇会逐行解释这份输出。

### 练习

- 运行 `sed --version`，确认你的版本。如果输出不是 GNU sed，安装 `gsed` 并重新检查。
- 运行 `bash scripts/check-env.sh`，记录退出码。
- 把 `examples/data/poem.txt` 里的 `blue` 换成 `BLUE`，只输出发生替换的行。
- 用 `sed --debug` 观察 `sed -n '2p' examples/data/poem.txt`，找出 `PATTERN`、`COMMAND` 和 `END-OF-CYCLE` 三类行。

<details>
<summary>参考答案</summary>

只输出发生替换的行：

```shell
sed -n 's/blue/BLUE/p' examples/data/poem.txt
```

预期输出：

```shell
violets are BLUE
```

`--debug` 会显示每一行都经过脚本，但只有第 2 行的地址 `2` 匹配，因此只有第 2 行执行了 `p`。这正是下一篇要展开的“地址决定命令作用范围”。

</details>

下一篇：[sed 的工作模型](how-sed-works.md)。
