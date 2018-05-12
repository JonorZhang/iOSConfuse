# ConfuseSwift

## 1.目录结构

```
- confuseAndBuild.sh # 混淆编译脚本
- [Example]     # 示例项目
- [Framework]   # 编译以后生成的通用framework
- [ConfuseFW]   # 框架源码
- ConfuseFW.xcodeproj
- ConfuseDemo.xcworkspace
- README.md
```

## 2.工程Scheme使用方法
- **DemoTest**   
编译Debug环境framework：只会编译当前设备对应架构，仅供测试用。
- **safeConfuseAndBuild**     
编译Release环境通用framework：编译时混淆代码，编译完去除混淆。
- **safeConfuse**     
安全混淆：备份源文件，然后混淆目标代码。
- **unconfuse**   
去除混淆：将备份源文件恢复。
- **Example**     
示例项目：框架使用Demo。

## 3. safeConfuseAndBuild.sh
这是swift代码混淆及编译的自动化脚本，使用编译时混淆的策略，不影响源码阅读，只需在想要混淆的函数名或者变量名前加个`private_`即可，可通过函数实现安全混淆、去混淆、混淆再编译。
