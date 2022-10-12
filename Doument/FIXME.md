#  FIXME

## Element

- [ ] [FIXME_E1] : [[Tower]] Working Copy 中的文件列表表格

### Accessibility Inspect

- [x] [FIXME_AI1](x-source-tag://FIXME_AI1) : "iMac > All pocesses" size 为 0，坐标偏移
    - size zero 改为 ⚠️

### CLion

- [ ] [FIXME_CL1] : 在副显示器上 y 坐标便宜了。`Accessibility Inspector` 也是。系统 BUG?
- [x] [FIXME_CL2](x-source-tag://FIXME_CL2) : Debugger 区域工具栏无法选择
    - `AXTabGroup` 中需要使用 `visibleChildren` 获取子元素，且获取的没有 `AXAction`
- [ ] [FIXME_CL3] : 打开的文件右边的 "x" 无法选中

### IDA

- [x] [FIXME_IA1](x-source-tag://FIXME_IA1) : 函数框无法选择，添加 `AXStaticText` 后也不行，函数不过滤还卡 3 秒
    - "AXTable" not have "AXVisibleRows" and children is too much! 
    - 使用行遍历算法

### iPhone Simulator

- [ ] [FIXME_IS1] : [Apple] 旋转后 frame 错误

### Logseq

- [x] [FIXME_LS1](x-source-tag://FIXME_LS1) : [[标签元素]] `#Swift` 
    - ~~在 `ElementTree.query()` 中没有递归到~~
    - 网页类 app 会调用 `TraverseSearchPredicateCompatibleWebAreaElementService` 中的方法进行遍历
    - [[标签元素]] 为 `AXStaticText`，需在 `searchKeys` 中添加 `AXStaticTextSearchKey`
- [ ] [FIXME_LS2] : 行末尾点击编辑行
- [ ] [FIXME_LS3] : 弹出设置后，仍然显示下面试图 Element

### Tower

- [x] [FIXME_TO1](x-source-tag://FIXME_TO1) : In `CTWorkingCopyOutlineView`, `NSOutlineRow` contains an `AXChekckBox`, but clicking on `AXChekckBox` does not select the row

### Xcode

- [x] [FIXME_XC1](x-source-tag://FIXME_XC1) : "Show the Variables View" and "Show the Console" 不能选中
    - 使用 Accessibility Inspector 查看为 ignored element，使用私有函数查找

## HelpView

- [X] [FIXME_HEV1](x-source-tag://FIXME_HEV1) : 快速切换状态时，延时显示错误

## HintView

- [ ] [FIXME_HV1](x-source-tag://FIXME_HV1) : NSScreen.screensHaveSeparateSpaces` (Mission Control -> Displays have separete Spaces(NO)) -| 修改 `HintsViewController.elementFrame(_:)` ？

## Menu 

- [x] [FIXME_M1](x-source-tag://FIXME_M1) : app1 打开菜单 -> 切换到 app2 -| `openedMenu` 未清空?
- [ ] [FIXME_M2] : [[lock]] on -> 打开菜单栏 submenu1 -> 打开 submenu2 -| submenu2 会消失，需要改为 move
- [x] [FIXME_M3] : [[Xcode]] [[AutoMenu]] 和 [[Lock]] 失效 
    - [FIXME_M4] 修复后，不 DEBUG Vimac 时正常
- [x] [FIXME_M4](x-source-tag://FIXME_M4) : 首次启动时，当前 app 的 [[Menu]] 失效，切换 app 后正常
    - 首次启动时，当前 app 不会发送 `NSWorkspace.didActivateApplicationNotification` 通知导致部分初始化失效，手动发送通知 
