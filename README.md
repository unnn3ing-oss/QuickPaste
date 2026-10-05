# QuickPaste（快速複製小工具）

一個給社群小編用的桌面小工具：把常用的文字（例如各粉專的 UTM 追蹤參數）做成按鈕，點一下就複製到剪貼簿。支援依粉專分類、值班時多選篩選，以及設定的匯出／匯入。

> 技術棧：.NET 8 + WPF（Windows）。原本的 PowerShell 版原型保留在 [`copy-tool.ps1`](copy-tool.ps1)。

## 功能

- **一鍵複製**：點按鈕直接把內容複製到剪貼簿，短暫顯示「已複製 ✓」。內容支援多行。
- **粉專分類**：每顆按鈕可指定分類（粉專），沒有分類的顯示為「未分類」。主頁面依分類分組排列，沒分類的排最後。
- **值班粉專篩選（可複選）**：左上角的篩選鈕可同時勾選多個分類，按鈕文字會顯示成「少康+娛樂」。彈出視窗內可用 ↑↓ 調整分類順序，順序會記住。
- **編輯模式**：直接改名稱、分類、複製內容，新增或刪除按鈕。每個欄位修改後立即存檔。分類欄可打字新增，也可從既有分類挑選。
- **左右滑動排版**：按鈕先往下排滿可見高度，再往右開新的一欄；滑鼠滾輪會轉成橫向捲動。
- **按鈕大小可調**：下方工具列的「－ ＋」調整，範圍 70–220 px，會記住。
- **視窗置頂**：右上角 📌 切換永遠置頂。
- **匯出／匯入設定**：見下方說明。

## 下載與執行

目前沒有提供編譯好的 `.exe`，需要自己建置。

1. 安裝 [.NET 8 SDK](https://dotnet.microsoft.com/download)。
2. 下載或 clone 這個 repo。
3. 在 `CopyTool` 資料夾執行：

   ```
   dotnet run
   ```

### 打包成免安裝單一 .exe

```
cd CopyTool
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

輸出位置：`CopyTool\bin\Release\net8.0-windows\win-x64\publish\CopyTool.exe`。這個 `.exe` 不需要另外安裝 .NET，可以直接帶到其他電腦使用。

## 資料存放位置

資料檔跟 `.exe` 放在**同一個資料夾**，整個資料夾一起帶著走就能搬家。

| 檔案 | 內容 |
|---|---|
| `copy-tool-buttons.json` | 所有按鈕（名稱、複製內容、分類） |
| `copy-tool-settings.json` | 視窗大小、按鈕大小、分類順序 |

這兩個檔案是個人的工作資料，已列入 `.gitignore`，**不會被提交到 repo**。如果要把這個 repo 公開，請不要把它們加進版本控制。

## 匯出／匯入

設定選單裡的「匯出設定」「匯入設定」可以備份或搬移資料。

匯出檔格式：

```json
{
  "Buttons": [
    { "Id": "f0360e8d", "Label": "主粉文字", "Text": "?&utm_source=facebook&utm_medium=fbarticlecomments", "Group": "主粉" }
  ],
  "GroupOrder": ["主粉", "少康", "娛樂"]
}
```

- 匯入會**整批取代**目前的按鈕。檔案若有問題（格式錯誤、沒有任何按鈕等），會顯示錯誤訊息，**目前的資料不會被動到**。
- 匯入同時接受舊格式（純按鈕陣列）。舊格式沒有分類順序，匯入後沿用目前的順序。
- 新格式的匯出檔，舊版 `copy-tool.ps1` 讀不了，因為它只認純陣列。

## 專案結構

```
CopyTool/
  MainWindow.xaml(.cs)   主視窗：按鈕格、編輯模式、篩選與排序
  Models/                ButtonItem、AppSettings、FilterOptionItem
  Services/
    JsonStore.cs         按鈕資料與匯出／匯入的讀寫
    SettingsStore.cs     視窗與分類順序設定
    CollectionSync.cs    差異更新清單（避免觸發 ComboBox 重設）
  Converters/            按鈕高度、標籤每 4 字換行
copy-tool.ps1            舊版 PowerShell 原型
HANDOFF.md               開發交接文件與功能規格
```

## 已知限制

- 僅支援 Windows（WPF）。
- 這個專案開發時沒有在 CI 或 Linux 環境編譯，WPF 介面部分請以你自己的 Windows 建置結果為準。

## 授權

尚未指定授權條款。
