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
| `AML.CALLJ.MB.DEMO.b` | SUBROUTINE (mainline, không tham số) | **Chạy trên T24 Model Bank thật**: đọc CUSTOMER thật (`F.READ`), CALLJ scan từng khách, hỏi approval cho hồ sơ bị hit. Chạy trong phiên T24 (PGM.FILE loại `M`) hoặc bằng `tRun`. Ghi kết quả ra console và `<TAFJ_HOME>/log/AML.CALLJ.MB.DEMO.log`. Không chạy trong trình giả lập |
| `AML.CALLJ.MB.DEMO.HIT.b` | SUBROUTINE (mainline, không tham số) | Kịch bản **hit cố định**: luôn quét CUSTOMER `10000083` (Solomon David). Mock đã có sẵn khách này trong watchlist nên kết quả là OVERRIDE rồi PENDING |
| `AML.MB.SCAN.CUSTOMERS.b` | SUBROUTINE | Phần xử lý dùng chung cho hai routine MB ở trên: khởi tạo phiên, đọc CUSTOMER, gọi CALLJ scan, kiểm tra approval/exposure, ghi log |
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

Quy tắc của mock: tên thuộc `NGUYEN VAN A`, `OSAMA BIN LADEN`, `JOHN DOE SANCTIONED` là trúng watchlist; quốc gia `KP/IR/SY/CU` bị cấm vận; tên `TRAN THI B` có adverse media; ClientID `WL000001` nằm trong whitelist; tên `SERVER ERROR` trả HTTP 500. Riêng demo Model Bank: tên `SOLOMON DAVID` và CUSTOMER ID `10000083` có sẵn trong watchlist.

Toàn bộ output của routine, mock và trình giả lập đều bằng tiếng Anh để demo cho khách nước ngoài.

## Điểm khác so với tài liệu training

1. **Cú pháp CALLJ.** Tài liệu viết `CALLJ <class> <method> <param> RETURNING <ret>`. Cú pháp của TAFJ/jBASE là:
   ```
   CALLJ packageAndClassName, [$]methodName, param SETTING ret [ON ERROR ... END]
   ```
   Các tham số cách nhau bằng dấu phẩy. Kết quả nhận qua `SETTING`. Method **static** phải có tiền tố `$` (vd `"$callRealTimeScan"`). Nếu không có `$`, CALLJ tạo object bằng constructor không tham số rồi gọi instance method. Trình giả lập vẫn nhận `RETURNING` để chạy được code viết theo tài liệu.
2. **Mã lỗi `SYSTEM(0)` trong `ON ERROR`:** 1 lỗi tạo thread, 2 không tạo được JVM, 3 không tìm thấy class, 4 lỗi Unicode, 5 không tìm thấy method, 6 không tìm thấy constructor, 7 không khởi tạo được object. Riêng mã 8 (Java method ném exception) chỉ có trong trình giả lập.
3. **Class/method thật:** `main.com.aml.AmlClient` với `callRealTimeScan`, `callRealTimeApprovalStatus`, `callRealTimeExposure`. Tài liệu dùng tên minh hoạ `com.temenos.aml.AmlScanner.scanCustomer`. Đầu vào là chuỗi phân cách `@`, không phải JSON; đầu ra là chuỗi phân cách `#`, nên T24 tách bằng `FIELD(...)` thay vì `MATCHES` trên JSON.

## Demo trên T24 Model Bank thật (mainline + mock server local)

```
 Máy T24 Model Bank (TAFJ)                                   Laptop demo
 ─────────────────────────                                   ───────────
 tRun AML.CALLJ.MB.DEMO 100100                               run-demo.bat mock
   ├ F.READ F.CUSTOMER (dữ liệu Model Bank)                  (Mock AML :8089)
   └ CALLJ main.com.aml.AmlClient.$callRealTimeScan ──HTTP──►  /AMLWS/api/...
         (aml-integration-full.jar trong classpath TAFJ)
```

### 1. Chọn URL để T24 gọi tới mock

| T24 chạy ở đâu | AML_URL |
|---|---|
| Cùng laptop với mock | `http://localhost:8089` |
| Máy/VM khác | `http://<IP laptop>:8089`. Khi khởi động, mock in ra các IP `reachable from T24 server as ...` |

Nếu T24 ở máy khác, mở port 8089 trên laptop (Windows, chạy với quyền Admin):
```bat
netsh advfirewall firewall add rule name="AML mock 8089" dir=in action=allow protocol=TCP localport=8089
```
Rồi kiểm tra từ máy T24: `curl http://<IP laptop>:8089/mock/state`.

### 2. Tạo gói triển khai

```bat
run-demo.bat package http://<IP laptop>:8089       REM Linux/Git Bash: ./run-demo.sh package http://...
```
Kết quả nằm trong `build\t24-deploy\`:

| Thư mục | Nội dung | Copy tới (trên máy T24) |
|---|---|---|
| `lib\aml-integration-full.jar` | AmlClient, **đã nhúng `aml.properties` trỏ tới mock** | classpath TAFJ (xem bước 3) |
| `lib\callj-training.jar` | `com.temenos.training.HelloWorld` | classpath TAFJ |
| `lib\thirdparty\*.jar` | httpclient5, httpcore5, jackson 2.15, sqlite-jdbc | classpath TAFJ. **Chỉ copy jar nào TAFJ chưa có**, tránh trùng version |
| `data\AMLScan.db` | Token cache rỗng | `%TAFJ_HOME%\data\` |
| `BP\*` | Các routine, tên file = tên routine | Thư mục BP của TAFJ |

Không cần copy `TAFJLogging.jar` và `libMonitor`, vì TAFJ runtime đã có sẵn.

### 3. Đưa jar vào classpath TAFJ

- **Chạy bằng `tRun`** (demo mainline): copy vào thư mục jar mở rộng của TAFJ, thường là `%TAFJ_HOME%\ext`, hoặc thư mục khai báo trong file `.properties` của project TAFJ.
- **Chạy qua Browser / app server** (VERSION routine): copy vào thư mục lib mà ứng dụng T24 dùng (tài liệu training ghi `BNK_EJB/lib`), rồi **restart app server**.

Đường dẫn cụ thể khác nhau tuỳ phiên bản và cách cài TAFJ, nên kiểm tra trên môi trường Model Bank của bạn. Nếu CALLJ báo `SYSTEM(0)=3` thì jar chưa nằm trong classpath.

### 4. Compile routine (subroutine trước, program sau)

```
tCompile AML.CALLJ.INVOKE
tCompile AML.SCAN.CUSTOMER
tCompile AML.MB.SCAN.CUSTOMERS
tCompile CALLJ.HELLO
tCompile AML.CALLJ.MB.DEMO
tCompile AML.CALLJ.MB.DEMO.HIT
tCompile V.AML.SCAN.CUSTOMER        (nếu demo thêm VERSION)
```

### 5. Chạy demo

Trên laptop: `run-demo.bat mock` (giữ cửa sổ mở để khách thấy request đến).

`AML.CALLJ.MB.DEMO` là SUBROUTINE không tham số, chạy được theo 2 cách:

**Cách 1: chạy trong phiên T24 đã login (không cần `OFS_SOURCE`)**
1. Tạo record `PGM.FILE` có ID `AML.CALLJ.MB.DEMO` và `AML.CALLJ.MB.DEMO.HIT`, `TYPE = M` (mainline). Nếu release yêu cầu thì tạo thêm `EB.API`.
2. Login T24, gõ trên command line rồi Enter:
   - `AML.CALLJ.MB.DEMO`: quét 5 khách hàng bất kỳ (thường ra PASS).
   - `AML.CALLJ.MB.DEMO.HIT`: quét CUSTOMER `10000083` Solomon David, ra **OVERRIDE** và approval **PENDING**.
3. Trên Browser, `CRT` không hiện ra màn hình, nên kết quả nằm ở `<TAFJ_HOME>\log\AML.CALLJ.MB.DEMO.log`. Mở file này (hoặc `type` trong CMD) để chiếu cho khách. Cửa sổ mock cũng hiện từng request.

**Cách 2: chạy từ console TAFJ bằng `tRun`**

Routine phải tự khởi tạo phiên qua `JF.INITIALISE.CONNECTION`, nên cần `OFS_SOURCE` là ID một record OFS.SOURCE có sẵn (xem `LIST F.OFS.SOURCE`):
```
set OFS_SOURCE=OFSONLINE
tRun CALLJ.HELLO                               kiểm tra CALLJ + classpath
tRun AML.CALLJ.MB.DEMO                         quét 5 khách hàng bất kỳ của Model Bank
tRun AML.CALLJ.MB.DEMO 100100 100724           quét khách hàng chỉ định (ID ví dụ, lấy ID thật bằng LIST F.CUSTOMER)
```
Hoặc dùng `run-mb-demo.bat [CUSTOMER.ID ...]` trong gói triển khai. Script này tự set `OFS_SOURCE=OFSONLINE` nếu chưa có.

Kịch bản hit dựng sẵn: chạy `AML.CALLJ.MB.DEMO.HIT` (hoặc `tRun AML.CALLJ.MB.DEMO.HIT`). Kết quả mong đợi:
```
--- CUSTOMER 10000083 ------------------------------------------------------------
Name        : Solomon David
Nationality : US   Year of birth: 1971   Gender: M   Legal ID: 10000083
CALLJ param : INPUTTER@GB0010001@CBS@10000083@1@Y@I@Y@Solomon David@US@1971@M@10000083@10000083@@@@@2#KH|KH|02|0|0|1|0
=> OVERRIDE : Customer is high risk by AML (watchlist match) - OnboardNo 1001

--- Approval status of AML hits ----------------------------------------------
CUSTOMER 10000083 / OnboardNo 1001
  Approval : P (PENDING - waiting for Compliance review)
  Exposure : Risk H - Solomon David  Watchlist=Y  PEP/RCA=PEP
```
Sau đó duyệt trên mock (`curl ".../mock/approve?onboardNo=<OnboardNo vừa ra>&status=A"`) và chạy lại: mỗi lần scan mock tạo OnboardNo mới, nên muốn thấy **APPROVED** thì kiểm tra đúng OnboardNo cũ bằng `run-demo.bat run AML.CHECK.APPROVAL 10000083 <OnboardNo>` trên laptop.

Với khách Model Bank khác (mặc định ra PASS), có thể tạo **hit trực tiếp** trước mặt khách:
```bat
curl "http://localhost:8089/mock/watchlist?addId=100100"            REM theo CUSTOMER ID
curl "http://localhost:8089/mock/watchlist?addName=ROBERT SMITH"   REM hoặc theo tên
```
Chạy lại (`tRun AML.CALLJ.MB.DEMO 100100`, hoặc gõ lại trên command line T24 sau khi `addId` đúng khách trong mẫu 5 khách) → **OVERRIDE**, có OnboardNo, approval **PENDING**. Sau đó:
```bat
curl "http://localhost:8089/mock/approve?onboardNo=1001&status=A"
```
Chạy lại lần nữa → approval **APPROVED**. Có thể nạp sẵn watchlist khi bật mock: `set MOCK_OPTS=-Dmock.watchlist.ids=100100,100724` rồi `run-demo.bat mock`.

### 6. (Tuỳ chọn) Demo trên màn hình Browser bằng VERSION

1. Tạo `EB.API` `V.AML.SCAN.CUSTOMER` (SOURCE.TYPE = BASIC).
2. Copy một VERSION CUSTOMER (vd `CUSTOMER,AML`) và đặt `INPUT.ROUTINE = V.AML.SCAN.CUSTOMER`.
3. Nhập khách tên `Nguyen Van A` → Commit → hiện override *"Customer is high risk by AML"*. Nhập quốc tịch `KP` → hiện error *"country is under sanction"*.

### Xử lý sự cố

| Hiện tượng | Nguyên nhân / cách xử lý |
|---|---|
| `CALLJ-3 Cannot find class` | Jar chưa có trong classpath TAFJ, hoặc chưa restart app server |
| `AML-API {"error": "Connect to ... refused"}` | Sai URL trong `aml.properties` (đã nhúng trong jar), mock chưa chạy, hoặc firewall chặn |
| `AML-API {"Message":"Authorization has been denied..."}` | Token cũ trong `AMLScan.db`. Xoá file DB, hoặc chờ 5 phút cho token hết hạn |
| `FATAL ERROR FROM T24.INITIALISE WARNING: OFS SOURCE ID not specified` | Chưa set `OFS_SOURCE`. Chạy `set OFS_SOURCE=<ID OFS.SOURCE>` rồi chạy lại |
| Các dòng `SLF4J(W): ...` | Chỉ là cảnh báo về logging binding của TAFJ, bỏ qua được |
| Lỗi khác ở `JF.INITIALISE.CONNECTION` / `LOAD.COMPANY` | Tuỳ release, mainline chạy ngoài phiên T24 cần khởi tạo khác. Có thể chạy từ phiên T24 đã login, hoặc chỉnh `INITIALISE.SESSION` |
| Không thấy output trong Browser | `CRT` chỉ hiện trên console. Dùng `tRun` cho mainline, dùng VERSION cho Browser |
| `%TAFJ_HOME%` chưa được set | Token không lưu được nhưng vẫn gọi được (mỗi lần lấy token mới) |

## Lưu ý về `AmlClient` phát hiện khi làm demo

- **Token cache không tự làm mới khi bị 401.** Nếu server AML thu hồi token hoặc restart mà token trong SQLite chưa hết hạn, mọi lời gọi sẽ lỗi cho tới khi token hết hạn. Demo xử lý bằng cách xoá DB khi `build` và dùng token không trạng thái trên mock. Hệ thống thật nên xoá cache và gọi lại `GetToken` một lần khi nhận 401.
- **`exposureFlag`, `cachedToken`, `tokenExpiryTime` là biến `static` dùng chung.** Trên TAFJ nhiều phiên chạy chung một JVM, nên khi Scan và Exposure chạy đồng thời có thể lấy nhầm token (AMLWS và AMLWS_EXPOSURE).
- Khi lỗi, `AmlClient` trả về JSON (`{"error": ...}`) hoặc nguyên body lỗi của API. `AML.CALLJ.INVOKE` coi mọi kết quả bắt đầu bằng `{` là lỗi.
