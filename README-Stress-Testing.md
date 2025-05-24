# 壓測實驗筆記：JMeter + Cloud Run + OpenTelemetry

## 一、測試概述
本次壓測目標為 `/api/employee`，透過 JMeter 模擬大量併發請求，並同時觀察 Cloud Run 與 OpenTelemetry 收集的各層指標，分析冷啟動、併發分流與延遲表現。

---

## 二、測試設定（Thread Group 參數）

| Parameter                  | Value   | 說明                                            |
|----------------------------|---------|-------------------------------------------------|
| Number of Threads (users)  | 800     | 同時模擬 800 位虛擬使用者                        |
| Ramp-Up Period (seconds)   | 1       | 在 1 秒內啟動所有執行緒（瞬間爆擊）               |
| Loop Count                 | Forever | 無限迴圈發送請求                                 |
| Specify Thread lifetime    | Duration=60s, Startup delay=0s | 每組執行緒持續 60 秒後自動停止       |
| HTTP Request               | GET `/api/employee` | 目標路徑                                |
| HTTP Header Manager        | Authorization: Bearer `<JWT>` | 加入認證 Token               |
| Listener                   | Summary Report, View Results Tree | 統計與除錯                          |


---

## 三、JMeter 結果摘要

| Column         | Value         | 解讀                                                                                       |
|----------------|---------------|--------------------------------------------------------------------------------------------|
| #Samples       | 2,413         | 總共發出 2,413 次請求                                                                      |
| Average (ms)   | 21,762        | 客戶端端到端平均延遲約 21.8 秒                                                              |
| Min (ms)       | 34            | 最快 0.034 秒                                                                              |
| Max (ms)       | 67,762        | 最慢 67.8 秒                                                                               |
| Std. Dev. (ms) | 26,851        | 延遲波動極大                                                                              |
| Error %        | 0.00%         | 全部請求都成功                                                                              |
| Throughput (/s)| 33.5          | 穩態平均每秒完成約 33.5 個請求（僅計算冷啟動後的穩定階段）                                    |
| Received KB/s  | 29.21         | 每秒從伺服器下載 29 KB                                                                     |
| Sent KB/s      | 12.32         | 每秒上傳 12 KB                                                                             |
| Avg. Bytes     | 894           | 每筆回應平均 894 bytes                                                                     |

> **關鍵觀察**：瞬間 800 條請求同時打入，Cloud Run cold start 約需 2–5 秒。在冷啟動期間大部分請求被卡住，導致端到端延遲大幅拉高。
---

## 四、Cloud Run 指標

### 4.1 Requests（完成率）

![Requests](./requests.png)  
- Y 軸：成功回應數（2xx）/ 秒（滑動平均、1m window）。  
- 峰值約 **30 req/s**，與 JMeter 穩態 Throughput（33.5）在同一量級。

### 4.2 容器執行個體數 (Active)

![Container Count](./container_count.png)  
- 壓測期間從 **2 → 10 個** 實例，**15 分鐘** 後縮回至 **2**。  
- 符合 `min_instance_count=2`、`max_instance_count=10`。

### 4.3 容器 CPU 使用率 (P50/P95/P99)

![CPU Usage](./cpu_usage.png)  
- P50 ≈ 0%，大部分時間無負載。  
- P95/P99 短暫衝至 100%，對應冷啟動與爆擊瞬間。

### 4.4 並行要求上限 (Per-Instance Concurrency)

![Concurrency](./concurrency.png)  
| Percentile | Color | 含意                                                    |
|------------|-------|---------------------------------------------------------|
| P50        | 藍    | 一半時間點下，單台實例的併發連線 ≤ 該值（接近 0）         |
| P95        | 紫    | 95% 時間點下，單台併發 ≤ 該值（達 ~90），超過 `concurrency=80` |
| P99        | 綠    | 99% 時間點下，單台併發 ≤ 該值（與 P95 重合，不易辨識）    |

> **說明**：單台實例若併發超過 80，就立即觸發 Scale-Out，再起新實例。此圖正好顯示 P95 ≈ 90，觸發了從 2 → 10 的擴容。

---

## 五、DB 與 Serverless VPC Connector 指標

### 5.1 資料庫伺服器 (DB Server) CPU 使用率

![DB Server CPU](./db_cpu.png)  
- 壓測高峰時，DB Server CPU 使用率只有 **約 40%**，遠低於 100%。  
- 這代表你在資料庫伺服器上的查詢、更新操作並未成為性能瓶頸。

### 5.2 Serverless VPC Access Connector

![VPC Connector](./vpc_connector.png)  
- Connector 實例數始終維持在 **2**（`min_instances=2, max_instances=2`），並未自動擴容。  
- CPU/網路 I/O 都保持在低位，顯示 2 台 Connector 已綽綽有餘。


---
## 六、OpenTelemetry 指標

> **Drilldown Filter**：`http_route="/api/employee"`, `http_request_method="GET"`, `http_response_status_code="200"`

### 6.1 Duration Bucket (Histogram)

![Bucket](./otel_bucket.png)  
- 各 latency 桶位 (0.0s…10s) 請求分佈熱力圖。  
- 壓測高峰 (03:46–03:47) 時，多數請求落在 0.5–5s，少數落在 5–10s。

### 6.2 Request Count (Counter)

![Count](./otel_count.png)  
- 每秒完成的 handler-level 請求數，峰值 ~**9–10 req/s**。  
- 低於 JMeter throughput，因 cold start 階段尚未計入 handler。

### 6.3 Duration Sum (Sum)

![Sum](./otel_sum.png)  
- 每秒累計延遲總和，峰值 ~**11–12 秒**。  
- 平均延遲可由 `sum/count` 計算：例如 `11s/9 ≈ 1.2s`。

---

## 七、指標差異與脈絡

| 層級         | 指標                 | 時間解析度      | 觀測值           | 差異原因                                |
|--------------|----------------------|---------------|------------------|-----------------------------------------|
| Client (JMeter) | Throughput (~33.5/s) | 整段穩態期平均  | 33.5 req/s       | 端到端延遲包含 cold-start，僅計算穩態期  |
| LB (Cloud Run) | Requests (~30/s)      | 1m 滑動平均     | 30 req/s         | Cold-start 期間完成率低，又用粗粒度平均   |
| App (OTel)   | Count (~9–10/s)      | 1s scrape     | 9–10 req/s       | 只計算 handler 完成呼叫，不含未結束請求   |



---

以上即為本次壓測全貌及各層指標分析，涵蓋測試設定、JMeter 報表、Cloud Run 自動擴縮機制、OpenTelemetry 應用層觀測以及各指標之間的差異。
