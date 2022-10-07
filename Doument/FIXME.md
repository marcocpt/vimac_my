#  FIXME

## Element

- [ ] [FIXME_E1] : [[Tower]] Working Copy 中的文件列表表格

### Logseq

- [x] [FIXME_LS1](x-source-tag://FIXME_LS1) : [[标签元素]] `#Swift` 
    - ~~在 `ElementTree.query()` 中没有递归到~~
    - 网页类 app 会调用 `TraverseSearchPredicateCompatibleWebAreaElementService` 中的方法进行遍历
    - [[标签元素]] 为 `AXStaticText`，需在 `searchKeys` 中添加 `AXStaticTextSearchKey`
- [ ] [FIXME_LS2] : 行末尾点击编辑行
- [ ] [FIXME_LS3] : 弹出设置后，仍然显示下面试图 Element

### Tower

- [x] [FIXME_TO1](x-source-tag://FIXME_TO1) : In `CTWorkingCopyOutlineView`, `NSOutlineRow` contains an `AXChekckBox`, but clicking on `AXChekckBox` does not select the row

## HelpView

- [X] [FIXME_HEV1](x-source-tag://FIXME_HEV1) : 快速切换状态时，延时显示错误

## HintView

- [ ] [FIXME_HV1](x-source-tag://FIXME_HV1) : NSScreen.screensHaveSeparateSpaces` (Mission Control -> Displays have separete Spaces(NO)) -| 修改 `HintsViewController.elementFrame(_:)` ？

## Menu 

- [x] [FIXME_M1](x-source-tag://FIXME_M1) : app1 打开菜单 -> 切换到 app2 -| `openedMenu` 未清空?
- [ ] [FIXME_M2] : [[lock]] on -> 打开菜单栏 submenu1 -> 打开 submenu2 -| submenu2 会消失，需要改为 move
- [ ] [FIXME_M3] : [[Xcode]] [[AutoMenu]] 和 [[Lock]] 失效 
