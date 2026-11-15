## GNU sed 入门

一份面向初学者的 GNU sed 教程，假设你已经会使用 shell：知道管道、重定向、引号和基本正则表达式。教程从 sed 的工作模型讲起，逐步进入地址、替换、正则、保持空间、多行处理和真实场景。核心示例都在 GNU sed 4.9 上实际运行过，平台差异单独标注。

**sed**(stream editor, 流编辑器) 一次读取一行，按脚本修改缓冲区，再输出结果。它不打开编辑器界面，也不要求把文件读进内存，因此特别适合管道、批处理和可重复的文本转换。

### 为什么学 sed

- **几乎无处不在**：Linux、macOS、BSD 和 Git Bash 都带有 sed，只是 GNU 与 BSD 版本存在差异。
- **适合管道**：可以从标准输入读、向标准输出写，容易和 `grep`、`sort`、`awk` 组合。
- **批量、可重复**：一条命令可以处理成百上千个文件，脚本可以进版本库、被审查。
- **理解文本处理的底层模型**：模式空间、地址、正则替换这些概念会迁移到 awk、Perl 和其他工具。
- **轻量**：不需要启动解释器或编辑器，处理大文件时内存占用通常很小。

### 学完能做什么

- 读懂并写出常见的 sed 单行命令和脚本文件。
- 用行号、正则和范围精确选择要处理的行。
- 用 `s` 命令、捕获组和替换转义完成批量修改与字段重排。
- 用保持空间和 `N`/`D` 完成跨行、去重、反转、合并等处理。
- 在修改文件前做备份、预览和差异检查，知道何时应该改用 awk、Perl 或 Python。
- 识别 GNU sed 与 BSD/macOS sed 的差异，写出可移植性符合预期的脚本。

### 不适合用 sed 的场景

sed 是**行导向的文本转换工具**，不是通用编程语言。遇到以下任务，优先换工具：

- 解析 JSON(JavaScript Object Notation)、XML(eXtensible Markup Language)、YAML(YAML Ain't Markup Language) 等有嵌套结构的格式：用 `jq`、`yq` 或对应语言的库。
- 带引号、转义和换行的 CSV(Comma-Separated Values, 逗号分隔值)：用 Python 的 `csv` 模块或 `awk` 的字段解析。
- 需要算术、聚合、排序、连接：用 `awk`、`sort`、`uniq` 或数据库。
- 需要复杂状态机、递归、错误处理：用 Python、Perl 或 Go。
- 交互式编辑、需要撤销和语法高亮：用编辑器。
- 二进制文件或需要保留任意字节的场景：确认工具行为后再用，通常不是 sed 的强项。

### 学习路径

按下面的顺序阅读，概念依赖最顺。标记为选学的章节不影响后面的实战，但会限制你能处理的文本类型。

| 顺序 | 文档 | 内容 | 建议 |
| --- | --- | --- | --- |
| 1 | [环境与约定](docs/setup.md) | 确认 GNU sed、准备数据、运行检查 | 必读 |
| 2 | [sed 的工作模型](docs/how-sed-works.md) | 模式空间、保持空间、自动打印、`-n` | 必读 |
| 3 | [地址与范围](docs/addresses.md) | 行号、正则、范围、`0,/re/`、`!` | 必读 |
| 4 | [替换命令 s](docs/substitute.md) | 标志、捕获组、`&`、`-i`、引号 | 必读 |
| 5 | [sed 的正则表达式](docs/regex.md) | BRE/ERE、字符类、边界、贪婪 | 必读 |
| 6 | [常用编辑命令](docs/editing-commands.md) | `p`、`d`、`a`、`i`、`c`、`y`、`q` | 必读 |
| 7 | [保持空间与流程控制](docs/hold-space.md) | `h/H/g/G/x`、标签、`b`/`t`/`T` | 选学 |
| 8 | [多行处理](docs/multiline.md) | `n`、`N`、`P`、`D`、`-z` | 选学 |
| 9 | [脚本化与可移植性](docs/scripts-and-portability.md) | `-f`、`-i` 安全、GNU/BSD 差异 | 必读 |
| 10 | [实战案例](docs/recipes.md) | 配置、日志、批量替换、模板、行尾 | 必读 |
| 11 | [排错与常见陷阱](docs/troubleshooting.md) | 症状、诊断、恢复 | 遇到问题先查 |
| 12 | [速查表](docs/cheatsheet.md) | 语法、选项、单行命令 | 学后查阅 |
| 13 | [综合练习](docs/capstone.md) | 用真实数据完成一组任务 | 选做 |

### 环境准备

教程以 **GNU sed** 为准。先确认版本：

```shell
sed --version
```

正常输出类似：

```shell
sed (GNU sed) 4.9
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
```

如果输出没有 `GNU sed`，说明你用的是 BSD sed 或其他实现：

- **macOS**：系统自带 BSD sed。安装 GNU 版并用 `gsed` 代替 `sed`：`brew install gnu-sed`。
- **Windows**：推荐 Git Bash(自带 GNU sed)或 WSL。PowerShell 里的 `sed` 可能是别名或第三方移植版，不保证行为一致。
- **Linux**：多数发行版预装 GNU sed；缺少时用包管理器安装，例如 Debian/Ubuntu 的 `sudo apt install sed`。

运行仓库自带的检查：

```shell
bash scripts/check-env.sh
```

### 五分钟体验

以下命令在仓库根目录执行。数据文件都是虚构的，IP(Internet Protocol) 地址使用文档保留地址段。

替换每行的第一个 `stream`：

```shell
sed 's/stream/line/' examples/data/poem.txt
```

只打印第二行：

```shell
sed -n '2p' examples/data/poem.txt
```

只打印发生替换的行：

```shell
sed -n 's/blue/BLUE/p' examples/data/poem.txt
```

按正则选择开发环境主机：

```shell
sed -n '/dev\.local/p' examples/data/hosts.txt
```

一次看 sed 的内部循环：

```shell
printf 'hello world\n' | sed --debug 's/world/sed/'
```

### 仓库结构

```shell
.
├── README.md
├── LICENSE                 MIT 许可证
├── docs/                   教程正文
├── examples/
│   ├── data/               练习与案例数据
│   └── scripts/            可复用的 sed 脚本
├── scripts/
│   ├── check-env.sh        环境检查
│   └── verify.sh           示例与行为的自动校验
├── .gitattributes
└── .gitignore
```

### 使用约定

- 所有命令默认在**仓库根目录**执行，路径写成 `examples/data/...`。
- 正文中的 `sed` 指 GNU sed；提到 macOS 系统自带的版本时会写 BSD sed 或 `gsed`。
- 标记 **GNU** 的写法是 GNU 扩展，POSIX 或 BSD sed 不一定支持。
- 命令块只放可复制命令；如果同一块里同时展示多条命令和输出，用 `$` 开头区分输入与输出，不要把 `$` 一起复制。
- 修改文件前先复制或使用备份后缀。教程中的 `-i` 示例会明确写出备份文件。
- 示例输出来自 GNU sed 4.9 的实际运行；涉及非 ASCII 字符的示例会显式指定 UTF-8 locale。平台差异会单独标注。
- 未实际运行的内容会写“示意”或“未验证”，不把推断当成实测。

### 练习与自检

每篇正文末尾有少量练习，答案折叠在“参考答案”里。建议先自己写出命令，再展开对照。

全部读完后运行：

```shell
bash scripts/verify.sh
```

它会用临时目录验证教程中的核心行为，不会修改仓库文件。如果你想验证自己的环境是否符合 GNU sed 的预期，也先运行它。

### 参考资料

- [GNU sed 官方手册](https://www.gnu.org/software/sed/manual/sed.html)：最权威的 GNU 行为说明。
- [POSIX sed 规范](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/sed.html)：可移植子集的边界。
- [sed one-liners](https://sed.sourceforge.net/sed1line.txt)：经典单行命令合集，注意其中不少是 GNU 扩展。
- [GNU 正则表达式语法](https://www.gnu.org/software/sed/manual/html_node/Regular-Expressions.html)：sed 使用的正则方言。

发现错误或希望补充案例，欢迎提交 issue 或 pull request。修改示例后请运行 `bash scripts/verify.sh`。

### 许可证

本项目采用 MIT 许可证，详见 [LICENSE](LICENSE)。
