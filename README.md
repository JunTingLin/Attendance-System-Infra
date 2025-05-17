# Attendance-System-Infra

## 1. 前置準備
+ 安裝 Terraform（建議使用 1.12.0 以上版本）
    + 參考 [Terraform 安裝教學](https://developer.hashicorp.com/terraform/install
    )
    + 終端機執行以下指令確認版本：
    ```
    terraform version
    ```

+ 在 GCP 已建立專案。
> 目前已建立，專案 ID 為：`tsmc-attendance-system-458811`

## 2. 服務帳戶金鑰取得
1. 到 GCP Console → IAM & Admin → Service Accounts 新增服務帳戶，例如`terraform-frontend`，角色選擇 `Owner擁有者`。

2. 在該帳戶點擊「新增金鑰」，選擇 JSON 格式，下載並存放到此repo的根目錄下。
> 目前服務帳戶`terraform-frontend`已經建立，金鑰檔案名稱為：`tsmc-attendance-system-458811-fe93d2e0516e.json`，放置在共用雲端硬碟內。

> 注意：不要將此金鑰推送到 GitHub。

## 3. 手動連結 GitHub 存放區
前往 GCP Console → Cloud Build → 存放區 → 第1代，手動連結你的 GitHub repo（如 後端倉庫Attendance-System-API 和前端倉庫
Attendance-System-frontend)。
![image](https://github.com/user-attachments/assets/03506b80-f991-4f60-876b-557e4a20af6b)

## 4. 配置 Secret Manager
基於安全考量，後端部分資訊需手動配置到 Secret Manager 中：
+ DB_PASS
+ DB_USER
+ JWT_SECRET
+ TELEGRAM_BOT_TOKEN

圖中，還有看到GitHub OAuth Token (github-connection-github-oauthtoken-96d120) 這是第3點**自動**生成的，理論上前端/後端repo 各一個Token
![image](https://github.com/user-attachments/assets/4ef6ea99-750b-4790-b778-f5bd2596d3d2)

## 5. 設定本機環境變數
+ 僅在當前會話有效，也就是當你關閉終端視窗後，該環境變數就會失效
+ 若沒有正確設定該環境變數，執行 GCP 相關操作時（如 terraform apply)將會出現 403 Forbidden 權限錯誤，因為沒有正確使用服務帳戶憑證授權。


Windows PowerShell：
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="tsmc-attendance-system-458811-fe93d2e0516e.json"
```

Linux/macOS 或 WSL (Bash)：
```bash
export GOOGLE_APPLICATION_CREDENTIALS="tsmc-attendance-system-458811-fe93d2e0516e.json"
```

## 6. Terraform 部署流程

1. 檢查 Terraform 配置檔中的 PROJECT_ID 是否已正確設定（目前已設定為 tsmc-attendance-system-458811，無需替換）。
> 假如為新的GCP專案，請將所有.tf文件 `PROJECT_ID` 替換為你的專案 ID。

2. 初始化 Terraform：
```
terraform init
```

3. 檢視 Terraform 執行計畫：
```
terraform plan
```

4. 部署 Terraform 資源：
```
terraform apply
```
執行時若出現確認提示，輸入 yes 繼續。

部署完成時，會顯示類似：
```
Apply complete! Resources: 18 added, 0 changed, 1 destroyed.
```

## 7. Cloud SQL Proxy 連線與資料匯入
1. 下載 [Cloud SQL Proxy](https://cloud.google.com/sql/docs/mysql/connect-auth-proxy?hl=zh-tw)，與金鑰 JSON 放在同一目錄。

2. 執行 Proxy (Windows PowerShell 範例)：
```
.\cloud-sql-proxy.exe `
  --port=3308 `
  --credentials-file="tsmc-attendance-system-458811-fe93d2e0516e.json" `
  tsmc-attendance-system-458811:asia-east1:attendance-mysql-instance
```

3. 使用資料庫工具 (如 Navicat, MySQL Workbench) 連接到本機`127.0.0.1:3008`

4. 匯入資料庫腳本，使用 [Attendance_System.sql](https://github.com/JunTingLin/Attendance-System-db/blob/main/Attendance_System.sql)。



### 8. Cloud Build 自動部署與手動觸發
+ 在後端 repo [Attendance-System-API](https://github.com/JunTingLin/Attendance-System-API) 已經配置了 [cloudbuild.yaml](https://github.com/JunTingLin/Attendance-System-API/blob/main/cloudbuild.yaml)。

+ 當推送到 main 分支 時會自動觸發 Cloud Build，打包成 Docker 映像，推送至 Artifact Registry，並部署到 Cloud Run。

+ 若需手動觸發：
    + 到 Cloud Build → 觸發條件，點擊由 IaC 建立的 attendance-build-trigger 旁的「執行」。
![image](https://github.com/user-attachments/assets/2974417e-5e99-43d3-9e73-468343d5694e)

+ 可以確認cloud Build 的紀錄是否為綠色成功勾勾。如為失敗可以到Logs Explorer 查看詳細錯誤訊息。
![image](https://github.com/user-attachments/assets/eacac5d9-c8ba-4529-b862-157fe7281219)

+ 進入 Cloud Run，點擊服務名稱，會看到服務的網址，這就是後端API的網址。
![image](https://github.com/user-attachments/assets/0c3d561a-5977-454d-8395-117d3e4e3178)


### 9. 清理資源
執行以下指令清除 Terraform 管理的資源：
```
terraform destroy
```

這邊我也不知道為何最後的網路相關服務無法刪除，但應該可以不必理會，這些服務網絡連接通常不會產生額外費用。
```
│ Error: Unable to remove Service Networking Connection, err: Error waiting for Delete Service Networking Connection: Error code 9, message: Failed to delete connection; Producer services (e.g. CloudSQL, Cloud Memstore, etc.) are still using this connection.
│ Help Token: AT3scP6hbfu80g4l4hclrxnKo-Pi7L5ISDAouij0PWbZ3C0dOGEKxwFNAQeed8hgH0CEkMZGXUEjiuwhySGtekIMy6jcDYY0bz9sUbOq6BEmZQ3I
```

### 補充
[Terraform 部署流程影片Demo](https://github.com/JunTingLin/Attendance-System-Infra/discussions/2)







