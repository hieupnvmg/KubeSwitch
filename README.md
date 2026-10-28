# KubeSwitch

Giao diện gồm danh sách file bên trái và bảng chọn context bên phải, có biểu tượng file, số context và trạng thái kích hoạt có màu. Menu bar đánh dấu context được chọn gần nhất trong app.

Ứng dụng macOS 13+ dành cho Apple Silicon (M1/M2/M3/M4/M5).

## Sử dụng

1. Mở KubeSwitch-macOS.dmg, kéo KubeSwitch.app vào Applications và mở app.
2. Bấm **Chọn thư mục…** và chọn thư mục chứa kubeconfig, ví dụ /Users/Apple.
3. Chọn file trong danh sách, chọn context, bấm **Kích hoạt context**.
4. kubectl và helm dùng ~/.kube/config sẽ sử dụng context đã chọn. Nếu terminal có biến KUBECONFIG, chạy `unset KUBECONFIG` trước.

App ghi nhớ thư mục đã chọn. Bấm biểu tượng ⎈ trên menu bar → chọn kubeconfig → chọn context để kích hoạt trực tiếp, không cần mở cửa sổ. Menu bar cũng có nút chọn thư mục, quét lại và mở cửa sổ. Sau khi kích hoạt, tên context xuất hiện trên menu bar; đây là lần chọn gần nhất trong app, không tự theo dõi thay đổi từ công cụ khác.

## Cách chuyển cấu hình

App sao chép nội dung kubeconfig, đặt current-context, chuyển đường dẫn chứng chỉ/key/tokenFile tương đối thành tuyệt đối rồi ghi ~/.kube/config. File nguồn được giữ nguyên, trừ khi bạn chọn chính ~/.kube/config. File đích được thay thế bằng file thường nếu trước đó là symlink.

Mỗi lần chuyển, cấu hình cũ được sao lưu ở ~/.kube/config.kubeswitch-backup-<UUID>. Đường dẫn bản sao lưu xuất hiện trong app. Có thể khôi phục bằng cách chép bản sao lưu đè lên ~/.kube/config. Các file được ghi với quyền 600.

App đọc cấu hình trên máy, không gọi cluster, không thực thi plugin xác thực và không gửi dữ liệu qua mạng. Khi dùng kubectl sau đó, kubectl có thể chạy plugin xác thực do kubeconfig chỉ định.

Quét đệ quy, bỏ qua thư mục ẩn trừ .kube, Library, Applications và node_modules; bỏ qua symlink và file lớn hơn 2 MB. Chỉ nhận YAML có clusters và contexts trong 8 KB đầu. Dùng Ruby có sẵn tại /usr/bin/ruby để đọc YAML an toàn; YAML có alias hoặc kiểu dữ liệu đặc biệt sẽ bị bỏ qua.

App được ký ad-hoc cục bộ, chưa được Apple notarize. Kiểm tra bằng `kubectl config current-context` sau khi kích hoạt. Chưa kiểm thử kết nối cluster thực tế.

## Biên dịch lại

Chạy trong thư mục chứa README này:

```sh
bash build.sh
```

Cần macOS và Xcode Command Line Tools. Script tạo app, ký ad-hoc và đóng gói DMG/ZIP trong dist/.
