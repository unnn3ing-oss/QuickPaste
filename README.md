# QuickPaste（快速複製小工具）

> ## ⬇️ 下載
>
> **[下載已編譯版（免安裝，約 67 MB）](https://github.com/unnn3ing-oss/QuickPaste/releases/latest/download/QuickPaste-portable.zip)**
>
> 解壓縮後，把自己的 `copy-tool-buttons.json`、`copy-tool-settings.json` 放在 `CopyTool.exe` 旁邊，雙擊 `CopyTool.exe` 就能用。**不需要安裝 .NET，也不用編譯。**每次更新 `main` 都會在雲端自動重新編譯這個檔案。
>
> 想自己編譯或修改程式？[下載原始碼（main.zip）](https://github.com/unnn3ing-oss/QuickPaste/archive/refs/heads/main.zip)，裝好 [.NET 8 SDK](https://dotnet.microsoft.com/download) 後雙擊 `publish.bat`，見下方[自己編譯](#自己編譯)。

一個給社群小編用的桌面小工具：把常用的文字（例如各粉專的 UTM 追蹤參數）做成按鈕，點一下就複製到剪貼簿。支援依粉專分類、值班時多選篩選，以及設定的匯出／匯入。

> 技術棧：.NET 8 + WPF（僅支援 Windows）。原本的 PowerShell 版原型保留在 [`copy-tool.ps1`](copy-tool.ps1)。

## 快速開始

1. 下載上方的已編譯版 zip，解壓縮到**有寫入權限的資料夾**（桌面、文件都可以，不要放在 `C:\Program Files`，因為資料檔會存在 `.exe` 旁邊）。
2. 想沿用自己的按鈕與設定，把 `copy-tool-buttons.json`、`copy-tool-settings.json` 放進同一個資料夾。沒有的話，第一次執行會看到兩顆範例按鈕，進「編輯」模式改成自己的內容即可，資料檔會自動建立。
3. 雙擊 `CopyTool.exe`。

整個資料夾可以直接搬到其他電腦，不用安裝。

## 功能

- **一鍵複製**：點按鈕直接把內容複製到剪貼簿，短暫顯示「已複製 ✓」。內容支援多行。
- **粉專分類**：每顆按鈕可指定分類（粉專），沒有分類的顯示為「未分類」。主頁面依分類分組排列，沒分類的排最後。
- **值班粉專篩選（可複選）**：左上角的篩選鈕可同時勾選多個分類，按鈕文字會顯示成「少康+娛樂」。彈出視窗內可用 ↑↓ 調整分類順序，順序會記住。
- **分類色帶**：每顆按鈕頂端有一條分類顏色的色帶，一眼分辨新聞、娛樂、少康等。顏色存在 `copy-tool-settings.json` 的 `GroupColors`（`#RRGGBB`），新分類會自動配色，也可以手動改。
- **開啟時詢問今天值班哪些粉專**：每次開啟會跳出視窗，勾選今天要顧的粉專，主畫面就只顯示那些分類的按鈕。預設全部不勾；按「顯示全部」或直接關閉就是不篩選。只有一個分類時不會跳出。值班中途要換，用下方的篩選鈕。
- **編輯模式**：直接改名稱、分類、複製內容，新增或刪除按鈕。每個欄位修改後立即存檔。分類欄可打字新增，也可從既有分類挑選。
- **左右滑動排版**：按鈕先往下排滿可見高度，再往右開新的一欄；滑鼠滾輪會轉成橫向捲動。
- **按鈕大小可調**：下方工具列的「－ ＋」調整，範圍 70–220 px，會記住。
- **視窗置頂**：右上角 📌 切換永遠置頂。
- **匯出／匯入設定**：見下方說明。

## 按鈕名稱怎麼換行

按鈕名稱最多顯示兩行，規則如下：

| 名稱怎麼寫 | 顯示結果 | 說明 |
|---|---|---|
| `新聞/文字` | 新聞<br>文字 | 名稱裡有 `/`：在第一個 `/` 換行，`/` 本身不顯示 |
| `新聞脆` | 新聞<br>脆 | 沒有 `/`：前兩個字為第一行，其餘為第二行 |
| `新聞Line推播` | 新聞<br>Line推播 | 同上 |
| `擠看看/` | 擠看看 | **結尾加 `/`**：不換行，整個名稱一行（`/` 不顯示） |
| `少康` | 少康 | 兩個字以內不換行 |

名稱最前面的 `/` 會被忽略。追蹤碼（複製內容）裡的符號不受影響。

## 資料存放位置

資料檔跟 `CopyTool.exe` 放在**同一個資料夾**，整個資料夾一起帶著走就能搬家。

| 檔案 | 內容 |
|---|---|
| `copy-tool-buttons.json` | 所有按鈕（名稱、複製內容、分類） |
| `copy-tool-settings.json` | 視窗大小、按鈕大小、分類順序、分類顏色 |

這兩個檔案是個人的工作資料，已列入 `.gitignore`，**不會被提交到 repo**，所以下載的 `main.zip` 裡沒有。要沿用自己的資料，把這兩個檔案放進 repo 根目錄（和 `publish.bat` 同一層）再執行 `publish.bat`，會一併打包進去；或直接複製到 `CopyTool.exe` 旁邊。

## 匯出／匯入

設定選單裡的「匯出設定」「匯入設定」可以備份或搬移資料。

匯出檔格式：

```json
{
  "Buttons": [
    { "Id": "f0360e8d", "Label": "新聞/文字", "Text": "?&utm_source=facebook&utm_medium=fbarticlecomments", "Group": "新聞" }
  ],
  "GroupOrder": ["新聞", "少康", "娛樂"]
}
```

- 匯入會**整批取代**目前的按鈕。檔案若有問題（格式錯誤、沒有任何按鈕等），會顯示錯誤訊息，**目前的資料不會被動到**。
- 匯入同時接受舊格式（純按鈕陣列）。舊格式沒有分類順序，匯入後沿用目前的順序。
- 新格式的匯出檔，舊版 `copy-tool.ps1` 讀不了，因為它只認純陣列。
- 注意：匯出檔是「匯入用」的格式，**不能**直接改名當 `copy-tool-buttons.json` 放在 `.exe` 旁邊（那個檔案要是純按鈕陣列）。要搬資料請用「匯入設定」。

## 自己編譯

需要 [.NET 8 SDK](https://dotnet.microsoft.com/download)（要 **SDK**，不是 Runtime）。

雙擊 repo 根目錄的 `publish.bat`，會產出：

- `dist\QuickPaste\`：`CopyTool.exe`，沒有 `.pdb`，整個資料夾可直接搬走使用。
- `dist\QuickPaste-portable.zip`：同樣內容的壓縮檔。

repo 根目錄若有 `copy-tool-buttons.json`、`copy-tool-settings.json`，會一併放進去。

公司電腦不能裝 SDK 也沒關係：編譯是在別台電腦（或直接用上方的已編譯版）做，產出的 `.exe` 已內含執行環境，拿去公司不用安裝任何東西。

## 自己開發／除錯

```
cd CopyTool
dotnet run
```

只想產出單一 `.exe`（不要資料夾與壓縮檔）：

```
cd CopyTool
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

輸出位置：`CopyTool\bin\Release\net8.0-windows\win-x64\publish\CopyTool.exe`。

## 常見問題

**雙擊 `CopyTool.exe` 出現「Windows 已保護您的電腦」？**
這個程式沒有數位簽章，從網路下載或傳給別人時，Windows SmartScreen 可能會擋。按「其他資訊」→「仍要執行」即可。

**`publish.bat` 說找不到 .NET SDK？**（只有自己編譯才會遇到）
安裝 [.NET 8 SDK](https://dotnet.microsoft.com/download)（不是 Runtime），裝完重新開啟視窗再執行。

**打包出來的 `.exe` 很大（約 150 MB）？**
因為裡面包了 .NET 執行環境，所以不用另外安裝。這是免安裝的代價。

## 專案結構

```
CopyTool/
  MainWindow.xaml(.cs)   主視窗：按鈕格、編輯模式、篩選與排序
  Models/                ButtonItem、AppSettings、FilterOptionItem
  Services/
    JsonStore.cs         按鈕資料與匯出／匯入的讀寫
    SettingsStore.cs     視窗與分類順序設定
    CollectionSync.cs    差異更新清單（避免觸發 ComboBox 重設）
    LabelFormatter.cs    按鈕名稱兩行顯示規則
    GroupColors.cs       分類色帶自動配色
    ButtonSizing.cs      按鈕字級隨寬度縮放
  GroupPromptWindow.xaml(.cs)  開啟時詢問今天值班哪些粉專
  Converters/            按鈕高度、標籤兩行顯示、字級、分類色帶
publish.bat              一鍵產出免安裝版（dist\）
copy-tool.ps1            舊版 PowerShell 原型
HANDOFF.md               開發交接文件與功能規格
```

## 已知限制

- 僅支援 Windows（WPF）。
- 專案目前沒有自動化測試。
- 程式沒有數位簽章，Windows SmartScreen 可能攔截，見下方常見問題。

## 授權

尚未指定授權條款。
