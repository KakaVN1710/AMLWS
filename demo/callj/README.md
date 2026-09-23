# Demo CALLJ từ T24 → AmlClient (AMLWS)

Demo này dựng lại luồng trong tài liệu *CALLJ Training in Temenos Transact (T24)* với code thật của repo:

```
 T24 routine (jBC)            TAFJ CALLJ               aml-integration-full.jar                Mock AML server
 ─────────────────            ──────────               ────────────────────────                ───────────────
 AML.CALLJ.DEMO / VERSION ──► CALLJ "main.com.aml.AmlClient", "$callRealTimeScan", param ──►  POST /AMLWS/api/GetToken
   └ AML.SCAN.CUSTOMER          (reflection, static          ├ GetToken + cache SQLite       POST /AMLWS/api/RealtimeScan
       └ AML.CALLJ.INVOKE        String m(String))           └ HTTP POST JSON                 POST /AMLWS/api/RealTimeApproval
                                                                                              POST /AMLWS_EXPOSURE/api/...
   ◄── "T#F#1001#...#H#..." (chuỗi phân cách '#') ◄──────────────────────────────────────────  JSON response
```

Không có môi trường T24 thật, nên demo gồm 3 phần:

| Thành phần | Thư mục | Vai trò |
|---|---|---|
| **Mock AML server** | `mock-server/` | Giả lập AMLWS + AMLWS_EXPOSURE (cùng URL trong `aml.properties`), có token, watchlist, cấm vận, whitelist, phê duyệt |
| **Routine T24 (jBC)** | `t24/BP/` | Routine jBC thật, cú pháp CALLJ của TAFJ/jBASE, dùng được trên T24 |
| **Trình giả lập TAFJ** | `t24-sim/` | `JbcRunner` đọc và chạy các file `.b`, trong đó CALLJ gọi Java qua reflection giống TAFJ (có `ON ERROR` và `SYSTEM(0)`) |

`AmlClient` được build trực tiếp từ `src/main` của repo thành `aml-integration-full.jar` rồi gọi qua CALLJ. Phần Java của repo không bị sửa.

## Chạy nhanh

Yêu cầu: JDK 17+ (đã thử với JDK 21).

```bash
cd demo/callj
./run-demo.sh            # build → bật mock → chạy CALLJ.HELLO + AML.CALLJ.DEMO → tắt mock
```

Chạy tương tác, ví dụ để demo phê duyệt của Compliance:

```bash
# Terminal 1
./run-demo.sh build
./run-demo.sh mock

# Terminal 2
./run-demo.sh run AML.CALLJ.DEMO                                   # tạo hồ sơ hit OnboardNo=1001 (PENDING)
curl "http://localhost:8089/mock/approve?onboardNo=1001&status=A"  # Compliance duyệt (A/R/P)
./run-demo.sh run AML.CHECK.APPROVAL 100002 1001                   # T24 hỏi lại → APPROVED
```

Trên Windows dùng `run-demo.bat build | mock | run <PROGRAM> [args]`.

## Routine T24 (`t24/BP`)

| Routine | Loại | Mô tả |
|---|---|---|
| `CALLJ.HELLO.b` | PROGRAM | Ví dụ HelloWorld trong tài liệu (mục 3–4) |
| `AML.CALLJ.INVOKE.b` | SUBROUTINE | Wrapper CALLJ dùng chung cho 3 API của `AmlClient`. Bắt `ON ERROR` và dịch `SYSTEM(0)`; nhận diện lỗi JSON mà AmlClient trả về |
| `AML.SCAN.CUSTOMER.b` | SUBROUTINE | Gọi `callRealTimeScan`, tách 11 trường kết quả và quyết định `PASS / OVERRIDE / BLOCK / ERROR` |
| `AML.CHECK.APPROVAL.SUB.b` | SUBROUTINE | Gọi `callRealTimeApprovalStatus` và `callRealTimeExposure` |
| `AML.CHECK.APPROVAL.b` | PROGRAM | `AML.CHECK.APPROVAL <ReferenceNo> <OnboardNo>` |
| `AML.CALLJ.DEMO.b` | PROGRAM | Kịch bản demo đầy đủ (bên dưới) |
| `V.AML.SCAN.CUSTOMER.b` | INPUT ROUTINE | Dùng trên **T24 thật**: gắn vào VERSION `CUSTOMER,...`, đọc `R.NEW`, sinh override (`STORE.OVERRIDE`) hoặc error (`STORE.END.ERROR`). Trình giả lập không chạy routine này |

### Kịch bản `AML.CALLJ.DEMO`

| # | Hồ sơ | Kết quả AmlClient (chuỗi `#`) | Quyết định T24 |
|---|---|---|---|
| 0 | HelloWorld | `Hello from Java: T24 Developer` | – |
| 1 | Heng Soka / US | `F#F#0####F####` | PASS |
| 2 | Nguyen Van A / VN (watchlist) | `T#F#1001#http://…/match/1001#H#F#F####` | OVERRIDE "Customer is high risk by AML" |
| 3 | Kim Chol / KP (cấm vận) | `F#F#1002##H##T####` | BLOCK (error) |
| 4 | Tran Thi B (adverse media) | `F#F#1003##M##F#T#…#T#…` | OVERRIDE "EDD required" |
| 5 | Nguyen Van A + ClientID `WL000001` | `F#T#0##L##F####` | PASS (whitelist) |
| 6 | Thiếu ClientName | `{"error": "ClientName is required"}` | Lỗi tích hợp |
| 7 | Approval + Exposure của hồ sơ 1001 | `P#Y` / `Risk H - Nguyen Van A#Y#WL01#PEP#P01#Y` | PENDING |
| 8 | Sai class / sai method / quên `$` | `ON ERROR`, `SYSTEM(0)` = 3 / 5 / 5 | – |

Thứ tự trường của chuỗi kết quả scan (theo `RealTimeScanResponse.toDelimitedString`):
`MatchStatus # WhitelistStatus # OnboardNo # MatchURL # RiskStatus # PassportStatus # SanctionCountryStatus # EDDStatus # EDDURL # AdvMediaStatus # AdvMediaURL`

Quy tắc của mock: tên thuộc `NGUYEN VAN A`, `OSAMA BIN LADEN`, `JOHN DOE SANCTIONED` là trúng watchlist; quốc gia `KP/IR/SY/CU` bị cấm vận; tên `TRAN THI B` có adverse media; ClientID `WL000001` nằm trong whitelist; tên `SERVER ERROR` trả HTTP 500.

## Điểm khác so với tài liệu training

1. **Cú pháp CALLJ.** Tài liệu viết `CALLJ <class> <method> <param> RETURNING <ret>`. Cú pháp của TAFJ/jBASE là:
   ```
   CALLJ packageAndClassName, [$]methodName, param SETTING ret [ON ERROR ... END]
   ```
   Các tham số cách nhau bằng dấu phẩy. Kết quả nhận qua `SETTING`. Method **static** phải có tiền tố `$` (vd `"$callRealTimeScan"`). Nếu không có `$`, CALLJ tạo object bằng constructor không tham số rồi gọi instance method. Trình giả lập vẫn nhận `RETURNING` để chạy được code viết theo tài liệu.
2. **Mã lỗi `SYSTEM(0)` trong `ON ERROR`:** 1 lỗi tạo thread, 2 không tạo được JVM, 3 không tìm thấy class, 4 lỗi Unicode, 5 không tìm thấy method, 6 không tìm thấy constructor, 7 không khởi tạo được object. Riêng mã 8 (Java method ném exception) chỉ có trong trình giả lập.
3. **Class/method thật:** `main.com.aml.AmlClient` với `callRealTimeScan`, `callRealTimeApprovalStatus`, `callRealTimeExposure`. Tài liệu dùng tên minh hoạ `com.temenos.aml.AmlScanner.scanCustomer`. Đầu vào là chuỗi phân cách `@`, không phải JSON; đầu ra là chuỗi phân cách `#`, nên T24 tách bằng `FIELD(...)` thay vì `MATCHES` trên JSON.

## Triển khai lên T24 thật (TAFJ)

1. Build `aml-integration-full.jar` (artifact IntelliJ hoặc `./run-demo.sh build` → `build/lib/`). Đặt jar cùng các thư viện trong `libs/` và `libMonitor/` vào classpath runtime của TAFJ (tài liệu ghi `BNK_EJB/lib/`; tuỳ cách cài có thể là thư mục `ext` của TAFJ). `AmlClient` dùng TemnLogger, nên thiếu `libMonitor` (OpenTelemetry) sẽ gây lỗi load class (CALLJ trả `SYSTEM(0)=3`).
2. Đặt `aml.properties` (URL/creds thật) vào classpath và bảo đảm `%TAFJ_HOME%/data/AMLScan.db` có bảng `credential`.
3. Compile các routine trong `t24/BP` bằng `tCompile`, rồi tạo `EB.API`/`PGM.FILE` theo quy trình của ngân hàng.
4. Gắn `V.AML.SCAN.CUSTOMER` vào `INPUT.ROUTINE` của VERSION CUSTOMER cần kiểm tra AML.

## Lưu ý về `AmlClient` phát hiện khi làm demo

- **Token cache không tự làm mới khi bị 401.** Nếu server AML thu hồi token hoặc restart mà token trong SQLite chưa hết hạn, mọi lời gọi sẽ lỗi cho tới khi token hết hạn. Demo xử lý bằng cách xoá DB khi `build` và dùng token không trạng thái trên mock. Hệ thống thật nên xoá cache và gọi lại `GetToken` một lần khi nhận 401.
- **`exposureFlag`, `cachedToken`, `tokenExpiryTime` là biến `static` dùng chung.** Trên TAFJ nhiều phiên chạy chung một JVM, nên khi Scan và Exposure chạy đồng thời có thể lấy nhầm token (AMLWS và AMLWS_EXPOSURE).
- Khi lỗi, `AmlClient` trả về JSON (`{"error": ...}`) hoặc nguyên body lỗi của API. `AML.CALLJ.INVOKE` coi mọi kết quả bắt đầu bằng `{` là lỗi.
