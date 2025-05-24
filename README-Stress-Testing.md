## 一、準備工作

1. 安裝 JMeter
    +  [Apache JMeter 5.6.3](https://jmeter.apache.org/download_jmeter.cgi)
    + 解壓後執行：
    ```bash
    # Linux / Mac
    bin/jmeter.sh
    # Windows
    bin\jmeter.bat
    ```
> JMeter 支援以 CLI（Command-Line Interface）方式執行，適合整合到 CI/CD pipeline

## 二、建立 Test Plan
1. 開啟 JMeter UI
畫面左上角預設一個空的 Test Plan。

2. 新增 Thread Group（模擬使用者群組）
    1. 右鍵點選 Test Plan
    2. 選擇 Add > Threads (Users) > Thread Group
    3. 設定 Thread Group 的參數
        - Number of Threads (users): 模擬的使用者數量，同時發出請求的執行緒數，例如 800
        - Ramp-Up Period (seconds): 所有使用者啟動的時間間隔，啟動 200 個執行緒所需時間，例如 1（秒）(瞬間爆擊)
        - Loop Count: 每個使用者執行的次數，測試迴圈次數。本次實驗請可勾選 Infinite 進行無限迴圈測試，並搭配 Scheduler 使用。
        - Scheduler(Specify Thread lifetime): 
            + Duration (seconds)：測試總時長，例如 120 秒
            + Startup delay (seconds)：啟動延遲時間，例如 0 秒

3. 新增 HTTP Request
    1. 右鍵點選剛才的 Thread Group
    2. 選擇 Add > Sampler > HTTP Request
    3. 設定 HTTP Request 的參數
        - Protocol: 協定類型
        - Server Name or IP: 目標伺服器的 IP 或網域名稱
        - Port Number: 目標伺服器的埠號
        - Method: HTTP 方法
        - Path: 請求的路徑

|       | localhost   | Cloud Run   |
| ----------- | ----------- | ----------- |
| Protocol      | HTTP       | HTTPS       |
| Server Name   | localhost        | attendance-system-api-752674193588.asia-east1.run.app/api/employee        |
| Port Number   | `8080`        | `443`        |
| Method   | `GET`        | `GET`        |
| Path   | `/api/employee`        | `/api/employee`        |

4. **新增 HTTP Header Manager**（設定 JWT Token）  
   1. 右鍵點選剛才的 Thread Group  
   2. 選擇 Add > Config Element > HTTP Header Manager  
   3. 在 Header Manager 裡新增一筆：  
      - **Name**: `Authorization`  
      - **Value**: `Bearer <your_JWT_token>`  

5. 新增 Listener（即時檢視結果）
    1. 右鍵點選剛才的 Thread Group
    2. 選擇 Add > Listener > Summary Report / View Results Tree


| 階段         | 推薦 Listener         | 原因                                           |
| ---          | ---                  | ---                                           |
| 開發／除錯    | View Results Tree    | 可以看到完整 request/response 內容，方便找問題   |
| 一次性大規模測試 | Summary Report       | 記憶體友善，快速呈現整體 Throughput、延遲等統計數字 |
| 同時關注錯誤率 | Aggregate Report     | 多出一個 “Error %” column，快速了解失敗請求比例 |
| 自動化／CI/CD | Backend Listener     | 可推送到 InfluxDB/Grafana，長期保存、圖表化、整合 Pipeline |



## 三、觀察雲端與後端指標

### 3.1 GCP Cloud Monitoring（USE 模型）
- **監控取向**：Usage, Saturation, Errors  
- **關鍵指標**：  
  - VPC Access Connector 實例數（無伺服器私有網路存取）  
  - Cloud Run Container instances 數量  
- **查看方式**：  
  1. **Cloud Console → Monitoring → Metrics Explorer**  
     - Metric: `vpc_access_connector.instances`、`run.googleapis.com/container/instance_count`  
  2. **Cloud Run 服務面板**  
     - 直接於 Cloud Run → 你的服務 → Metrics 分頁  
  3. **VPC Network → Serverless VPC Access**  
     - 查看 Connector 狀態與使用量  

### 3.2 Java OpenTelemetry Agent（RED 模型）
- **監控取向**：Rate, Errors, Duration  
- **關鍵指標**：  
  - `http_server_request_duration_seconds_bucket`
    - Histogram 各 latency 桶 (bucket) 的請求數分佈
    - X 軸為時間、Y 軸為每個桶的範圍 (0.005s, 0.01s, …, 10s)
    - 顏色深淺代表該桶在該時間點的請求量大小
  - `http_server_request_duration_seconds_count`
    - 每個時間區間內的請求總數 (counter)
    - 對應 JMeter Summary Report 的 #Samples / 時間窗口
  - `http_server_request_duration_seconds_sum`
- **解讀說明**：  
  1. **Request Rate** (`count`)：每秒請求量 = Δcount/Δtime  
  2. **Error Rate** (可用 `http_server_requests_errors_total`、或比對 status code)  
  3. **Latency**：平均延遲 = `sum / count`；Percentile 延遲由 bucket 計算，如 p95、p99 等  


## 四、觸發與擴展原理

### 1. Cloud Run

- **Scale-Out（擴展）**  
  - 每個實例預設可同時處理 **80** 個併發請求（可透過 `concurrency` 調整）。  
  - 當同時請求數 > `現有實例數 × concurrency` 時，Cloud Run 會自動啟動新實例，直到達到 `max_instance_count=10`。  
  - **Cold start 時間**：依 runtime 而異，約需 **1–10 秒**。

- **Scale-In（縮減）**  
  - 空閒實例在處理完最後一筆請求後，**最多保留 15 分鐘** 再回收。  
  - 已設定 `min_instance_count=2`，即使長時間無流量，也會維持至少 **2** 個實例隨時待命，不會降到 0。

### 2. Serverless VPC Access Connector

- **Scale-Out（擴展）**  
  - 當流量需求增加，Connector 實例數會從 `min_instances=2` 自動擴展至 `max_instances=3`。

- **Scale-In（縮減）**  
  - **不會** 自動縮減實例數；若要降到更低，必須透過 Terraform 更新或重建該資源。


## 五、2025/05/24 03:46 測試結果
### 1. 設定按照第二點的 Thread Group 參數，執行並觀察

### 2. JMeter Report
#### summary Report
+ #Samples = 2413：執行了 2,413 次請求
+ Average = 21762 ms：平均每次要等 21.7 秒才拿到回應
+ Min = 34 ms / Max = 67762 ms：最快 0.034 秒、最慢 67.8 秒
+ Std. Dev. = 26851.17 ms：延遲相當不穩定，有很大波動
+ Error % = 0.00%：沒有任何失敗請求
+ Throughput = 33.5/sec：測試期間內，你每秒大概落地 33.5 個請求
+ Received KB/sec = 29.21 / Sent KB/sec = 12.32：下載速率約 29 KB/s，上傳速率約 12 KB/s
+ Avg. Bytes = 894：每次回傳內容約 894 bytes

> 這裡數字不太理想，推測原因是Ramp-Up 設為 1 秒(瞬間爆擊)，代表所有使用者幾乎同時在 1 秒內一起衝 800 條請求，Cloud Run 要從 2 → 10 個 instance，cold-start 時間平均約 2–5 秒，在這幾秒內，幾乎所有的請求都打到還沒就緒的實例上，就會「卡住等回應」，才會看到平均 21.7 秒、最大 67.7 秒的超長延遲。

#### View Results Tree
從圖可看到所有請求都有正確拿到employee 資料，200 OK。


### 3. cloud run 指標
+ Requests（完成率）
  - **Y 軸**：成功回應數（2xx）/ 秒。  
  - **觀察**：高峰僅 ~30 req/s，因大批請求在 cold-start 階段仍在等待中，只有少部分完成。

+ 容器執行個體數 (Active)  
  - 壓測期間從 **2 → 10 個** 實例，隨後在約 **15 分鐘** 後回落至 **2**。  
  - 與 `min_instance_count=2`, `max_instance_count=10` 相符。

+ 容器 CPU 使用率 (P50/P95/P99)  
  - 大部分時間無負載。  
  - 短暫衝至 ~100%，對應冷啟動及初期流量。  
  - 代表僅在啟動與爆擊時出現高負載，其餘時間實例都在空閒。

+ 並行要求上限 (Concurrency) 
  - **P95 (紫點)**  
  - 壓測高峰時達到約 **90 條** in-flight 請求，超出每台 `concurrency=80` 的設定  
  - 因此在這個時刻 Cloud Run 自動再起新實例  
  - **P50 (藍點)**  
    - 多數時間維持接近 **0**，因為在 scale-out 完成後，流量分散至多台實例，其中一半以上的樣本點閒置中  
  - **P99 (綠點)**  
    - 線條未明顯分離，常與 P95 重合，極端樣本又較少，圖上不易辨識  
  - **重點**  
    - 此圖展示的是 **單台實例** 的併發連線數，並非所有實例加總  
    - 只要任一實例的併發超過 80，就會觸發 Scale-Out 至下一台

### 6. 資料庫&Serverless VPC Access Connector 指標
Connector 只有 2 台，但是它的處理能力還沒被耗盡（例如 queue、CPU 都沒飽和），所以不會啟動更多

DB CPU 峰直只有 40%


### 5. OpenTelemetry 指標
以下三個面板透過 Grafana 讀取你的 OpenTelemetry Export，針對 `/api/employee` (GET, 200) 的請求進行分析。

+ http_server_request_duration_seconds_bucket
  - 這是一張 Histogram 各 latency bucket 的請求數分佈熱力圖。  
  - X 軸顯示時間範圍，Y 軸顯示延遲桶位 (0.0s、0.01s、0.05s、0.1s、0.5s、1s、5s、10s)。  
  - 顏色深淺代表該桶位在該時間點的請求量大小，深色表示請求量較多。  
  - 壓測高峰 (03:46–03:47) 時，大多數請求落在 0.5–5 秒桶位，少數請求分佈到 5–10 秒。

+ http_server_request_duration_seconds_count
  - 此面板顯示每秒完成的請求總數 (counter)。  
  - 該圖的峰值約為 9–10 requests/s，代表在應用程式層面實際處理並結束的請求速率。  
  - JMeter 的 Summary Report 在 60 秒內發出了 2,413 次請求，理論上平均 throughput 為 40.2 requests/s，但 OpenTelemetry count 僅統計 handler level 的完成請求量，且各實例分流後的結果較低。

+ http_server_request_duration_seconds_sum
  - 此面板顯示每秒內所有請求延遲的總和，以秒為單位 (sum)。  
  - 壓測高峰時，sum 約落在 10–12 秒之間。  
  - 可透過 `Avg Latency = sum / count` 計算平均延遲，例如在某秒 `sum ≈ 11s`、`count ≈ 9`，則平均延遲約 1.2 秒。




