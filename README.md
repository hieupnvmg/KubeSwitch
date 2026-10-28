# KubeSwitch

Giao diện gồm danh sách file bên trái và bảng chọn context bên phải, có biểu tượng file, số context và trạng thái kích hoạt có màu. Menu bar đánh dấu context được chọn gần nhất trong app.

Ứng dụng macOS 13+ dành cho Apple Silicon (M1/M2/M3/M4/M5).

## Sử dụng

1. Mở KubeSwitch-macOS.dmg, kéo KubeSwitch.app vào Applications và mở app.
2. Bấm **Chọn thư mục…** và chọn thư mục chứa kubeconfig, ví dụ /Users/Apple.
3. Chọn file trong danh sách, chọn context, bấm **Kích hoạt context**.
4. kubectl và helm dùng ~/.kube/config sẽ sử dụng context đã chọn. Nếu terminal có biến KUBECONFIG, chạy `unset KUBECONFIG` trước.

## Tìm kiếm (từ 1.3.0)

Nhập vào ô **Tìm file, đường dẫn hoặc context…** ở trên danh sách để lọc ngay các kết quả đã quét. Không phân biệt chữ hoa/thường và dấu. Có thể nhập nhiều từ, ví dụ `team prod`, để tìm context prod trong đường dẫn có team. Danh sách context cũng được lọc theo từ khóa; xóa ô tìm kiếm để hiện lại tất cả.

Trong menu bar, chọn **Tìm kiếm…** để mở cửa sổ và đưa con trỏ vào ô tìm kiếm. Danh sách chọn nhanh trên menu bar dùng cùng bộ lọc, có mục **Xóa bộ lọc**. Tìm kiếm hoạt động trên những file đã tìm thấy, kể cả trong lúc quét; không quét lại ổ đĩa khi gõ.

Kiểm tra bộ lọc: `mkdir -p dist && swiftc Search.swift tests/SearchTests.swift -o dist/SearchTests && dist/SearchTests`.

## Quét thư mục

Mặc định quét file trong thư mục đã chọn và tối đa **3 cấp thư mục con**. Có thể chọn 1 cấp, 3 cấp, 6 cấp hoặc không giới hạn; bấm **Quét lại** để áp dụng. App ghi nhớ lựa chọn này.

Kết quả xuất hiện ngay khi tìm thấy. Trong khi quét, app hiển thị số file đã kiểm tra, số kubeconfig tìm thấy, số mục bỏ qua và đường dẫn đang xử lý. Số mục bỏ qua gồm thư mục bị loại, symlink, file nhị phân/lớn và lỗi đọc hoặc YAML; đây không phải tỷ lệ phần trăm vì chưa biết tổng số file.

Bấm **Hủy quét** trong cửa sổ hoặc menu bar để dừng và giữ lại kết quả đã tìm thấy. Khi quét hoàn tất hoặc đã hủy, có thể kích hoạt context trong các kết quả đó. Với thư mục lớn, nên bắt đầu ở độ sâu 1 hoặc 3 cấp và tăng nếu thiếu file.

App ghi nhớ thư mục đã chọn. Bấm biểu tượng ⎈ trên menu bar → chọn kubeconfig → chọn context để kích hoạt trực tiếp, không cần mở cửa sổ. Menu bar cũng có nút chọn thư mục, quét lại và mở cửa sổ. Sau khi kích hoạt, tên context xuất hiện trên menu bar; đây là lần chọn gần nhất trong app, không tự theo dõi thay đổi từ công cụ khác.

## Cập nhật OTA (từ 1.2.0)

Bấm **Kiểm tra cập nhật…** ở cuối cửa sổ hoặc trong menu bar. Nếu có bản mới, Sparkle sẽ cho tải và **Install and Relaunch** để thay app và mở lại. Không cần tải DMG mỗi lần. Có thể cần xác thực của macOS nếu thư mục cài đặt yêu cầu quyền ghi.

Mặc định app tự kiểm tra khoảng mỗi 24 giờ, nhưng vẫn yêu cầu người dùng chọn cài đặt. Bật/tắt **Tự kiểm tra cập nhật** trong menu bar. App dùng feed và file ZIP từ GitHub qua HTTPS; cả feed và file cập nhật đều được kiểm tra chữ ký Ed25519 trước khi xử lý.

**Bản 1.1.0 trở về trước chưa có updater:** tải DMG 1.2.0 và thay app trong Applications một lần. Những lần sau cập nhật trong app. Chạy app đã cài trong Applications, thay vì chạy từ ổ DMG chỉ đọc.

## Cách chuyển cấu hình

App sao chép nội dung kubeconfig, đặt current-context, chuyển đường dẫn chứng chỉ/key/tokenFile tương đối thành tuyệt đối rồi ghi ~/.kube/config. File nguồn được giữ nguyên, trừ khi bạn chọn chính ~/.kube/config. File đích được thay thế bằng file thường nếu trước đó là symlink.

Mỗi lần chuyển, cấu hình cũ được sao lưu ở ~/.kube/config.kubeswitch-backup-<UUID>. Đường dẫn bản sao lưu xuất hiện trong app. Có thể khôi phục bằng cách chép bản sao lưu đè lên ~/.kube/config. Các file được ghi với quyền 600.

App đọc cấu hình trên máy, không gọi cluster, không thực thi plugin xác thực và không tải kubeconfig lên mạng. Phần cập nhật có kết nối GitHub để đọc feed và tải phiên bản mới. Khi dùng kubectl sau đó, kubectl có thể chạy plugin xác thực do kubeconfig chỉ định.

Quét theo từng cấp, ưu tiên tên file có kube/config hoặc đuôi YAML trong mỗi thư mục. Bỏ qua thư mục ẩn trừ .kube, Library, Applications, node_modules, vendor và Pods; bỏ qua symlink, bản sao lưu do app tạo, các đuôi file nhị phân phổ biến và file lớn hơn 2 MB. Đọc nội dung file còn lại trong giới hạn 2 MB, nên nhận được cả kubeconfig có clusters/contexts nằm sau 8 KB đầu. Dùng Ruby có sẵn tại /usr/bin/ruby để đọc YAML an toàn; YAML có alias hoặc kiểu dữ liệu đặc biệt sẽ bị bỏ qua.

App được ký ad-hoc cục bộ, chưa được Apple notarize. Kiểm tra bằng `kubectl config current-context` sau khi kích hoạt. Chưa kiểm thử kết nối cluster thực tế.

## Biên dịch lại

Chạy trong thư mục chứa README này:

```sh
bash build.sh
```

Cần macOS và Xcode Command Line Tools. Script tạo app, ký ad-hoc và đóng gói DMG/ZIP trong dist/.

Build tải Sparkle 2.10.1 từ bản phát hành chính thức và kiểm tra SHA-256 đã ghim trước khi giải nén. Giấy phép Sparkle được đóng kèm trong Resources của app. Tài liệu: [Sparkle](https://sparkle-project.org/documentation/).

Kiểm tra cơ chế quét bằng `python3 -m unittest -v test_scan.py` (cần Python 3). Bộ kiểm tra bao gồm giới hạn độ sâu, thư mục/file bị loại, YAML có trường nằm sau 8 KB đầu, tên Unicode, kết quả dạng stream, dừng tiến trình và lỗi thư mục không tồn tại.

## Phát hành bản cập nhật

1. Tăng cả CFBundleVersion (số build) và CFBundleShortVersionString trong Info.plist.
2. Chạy `bash prepare-update.sh`. Script build app và tạo appcast.xml có chữ ký. Cần khóa ký gốc trong login Keychain, account `hieupnvmg.KubeSwitch`. Script kiểm tra public key khớp Info.plist trước khi ký.
3. Commit/push mã nguồn (chưa push feed), tạo GitHub Release `v<version>` và tải `dist/KubeSwitch-macOS.zip` cùng DMG lên release đó. ZIP phải là chính file đã ký, không được build/đóng gói lại sau khi tạo feed.
4. Sau khi asset tồn tại, commit/push appcast.xml lên main. Không sửa tay file này sau khi ký. Có thể đính kèm appcast.xml vào release để tham khảo, nhưng updater lấy feed từ main.

Khóa riêng nằm trong Keychain, không nằm trong repository. Người giữ khóa cần sao lưu an toàn bằng công cụ `generate_keys --account hieupnvmg.KubeSwitch -x <file-private>` rồi lưu bản xuất ở nơi bảo mật; không commit file xuất. Mất khóa có thể buộc người dùng cài lại thủ công vì bản phân phối hiện tại chưa có Developer ID để hỗ trợ xoay khóa.

Sau khi tạo feed, chạy `python3 test_updates.py`: một app kiểm tra tạm thời dùng chính API Sparkle xác nhận nhận được bản mới, từ chối feed bị sửa và từ chối archive bị sửa. Kiểm tra này không cài app hay sửa kubeconfig; nó không mô phỏng bước cài đặt và mở lại trên máy người dùng.
