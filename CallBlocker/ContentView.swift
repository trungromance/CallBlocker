import SwiftUI
import CallKit

struct ContentView: View {
    @State private var isMasterEnabled: Bool = BlockListManager.shared.isMasterEnabled
    @State private var rules: [BlockPrefixRule] = []
    
    // Form Input
    @State private var newPrefix: String = ""
    @State private var newNote: String = ""
    @State private var countryCode: String = "84"
    @State private var totalDigits: Int = 10
    
    // Status & UI State
    @State private var extensionStatusText: String = "Đang kiểm tra..."
    @State private var isExtensionEnabledInSettings: Bool = false
    @State private var isReloading: Bool = false
    @State private var alertMessage: String = ""
    @State private var showAlert: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // MARK: - 1. CÔNG TẮC BẬT / TẮT CHÍNH
                Section(header: Text("TRẠNG THÁI HỆ THỐNG").font(.caption).foregroundColor(.gray)) {
                    Toggle(isOn: $isMasterEnabled) {
                        HStack {
                            Image(systemName: isMasterEnabled ? "shield.fill" : "shield.slash.fill")
                                .foregroundColor(isMasterEnabled ? .green : .red)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isMasterEnabled ? "Chế độ Chặn: ĐANG BẬT" : "Chế độ Chặn: ĐANG TẮT")
                                    .fontWeight(.bold)
                                Text(isMasterEnabled ? "Tự động từ chối mọi cuộc gọi từ đầu số đã thêm" : "Tạm dừng chặn tất cả cuộc gọi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onChange(of: isMasterEnabled) { newValue in
                        BlockListManager.shared.isMasterEnabled = newValue
                        syncWithCallKitSilently()
                    }
                    
                    // Trạng thái cấp quyền trong Cài đặt iPhone
                    HStack {
                        Image(systemName: isExtensionEnabledInSettings ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isExtensionEnabledInSettings ? .green : .orange)
                        Text("Quyền iOS: \(extensionStatusText)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if isReloading {
                            ProgressView().scaleEffect(0.8)
                        }
                    }
                }
                
                // MARK: - 2. NHẬP ĐẦU SỐ MỚI
                Section(header: Text("THÊM ĐẦU SỐ CẦN CHẶN").font(.caption).foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("+84")
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                                .font(.system(.body, design: .monospaced))
                            
                            TextField("Ví dụ: 059 hoặc 0592*", text: $newPrefix)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        TextField("Ghi chú (Ví dụ: Spam tài chính, Telesale)", text: $newNote)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.footnote)
                        
                        Button(action: addPrefix) {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                Text("Thêm Vào Danh Sách Chặn")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .background(newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - 3. DANH SÁCH CÁC ĐẦU SỐ ĐANG CHẶN
                Section(header: HStack {
                    Text("DANH SÁCH ĐẦU SỐ BỊ CHẶN (\(rules.count))")
                    Spacer()
                }.font(.caption).foregroundColor(.gray)) {
                    if rules.isEmpty {
                        Text("Chưa có đầu số nào. Hãy nhập đầu số (như 059) ở trên để bắt đầu.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(rules) { rule in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text("\(rule.prefix)*")
                                            .font(.system(.headline, design: .monospaced))
                                            .foregroundColor(.red)
                                        Text("(Độ dài: \(rule.totalDigits) số)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    if !rule.note.isEmpty {
                                        Text(rule.note)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: { rule.isEnabled },
                                    set: { _ in
                                        BlockListManager.shared.toggleRule(id: rule.id)
                                        loadRules()
                                        syncWithCallKitSilently()
                                    }
                                ))
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteRules)
                    }
                }
                
                // MARK: - 4. HƯỚNG DẪN VÀ NÚT MỞ CÀI ĐẶT
                Section(header: Text("CÀI ĐẶT QUYỀN TRÊN IPHONE").font(.caption).foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Để chặn cuộc gọi, bạn cần cấp quyền cho ứng dụng:")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Mở **Cài đặt** ➔ **Điện thoại** ➔ **Chặn & Nhận dạng cuộc gọi**.")
                                .font(.footnote)
                        }
                        
                        HStack(alignment: .top, spacing: 8) {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Bật công tắc của **Chặn số rác** sang màu xanh.")
                                .font(.footnote)
                        }
                        
                        // Nút chuyển nhanh vào Cài đặt iOS
                        Button(action: openPhoneSettings) {
                            HStack {
                                Spacer()
                                Image(systemName: "gearshape.fill")
                                Text("Mở Cài Đặt (Settings) iPhone")
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.up.right")
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Chặn Số Rác")
            .onAppear {
                loadRules()
                checkExtensionStatus()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Lưu ý"), message: Text(alertMessage), dismissButton: .default(Text("Đã hiểu")))
            }
        }
    }
    
    private func loadRules() {
        self.rules = BlockListManager.shared.getRules()
    }
    
    private func addPrefix() {
        let clean = newPrefix.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        BlockListManager.shared.addRule(prefix: clean, totalDigits: totalDigits, countryCode: countryCode, note: newNote)
        newPrefix = ""
        newNote = ""
        loadRules()
        syncWithCallKitSilently()
    }
    
    private func deleteRules(at offsets: IndexSet) {
        BlockListManager.shared.removeRule(at: offsets)
        loadRules()
        syncWithCallKitSilently()
    }
    
    private func checkExtensionStatus() {
        BlockListManager.shared.checkExtensionStatus { status, error in
            if let error = error {
                self.extensionStatusText = "Không thể kiểm tra (\(error.localizedDescription))"
                self.isExtensionEnabledInSettings = false
                return
            }
            switch status {
            case .enabled:
                self.extensionStatusText = "Đã kích hoạt"
                self.isExtensionEnabledInSettings = true
            case .disabled:
                self.extensionStatusText = "Chưa bật quyền"
                self.isExtensionEnabledInSettings = false
            case .unknown:
                self.extensionStatusText = "Chưa xác định"
                self.isExtensionEnabledInSettings = false
            @unknown default:
                self.extensionStatusText = "Không xác định"
                self.isExtensionEnabledInSettings = false
            }
        }
    }
    
    // Tự động đồng bộ ngầm mượt mà, không bật popup làm phiền người dùng
    private func syncWithCallKitSilently() {
        isReloading = true
        BlockListManager.shared.reloadExtension { error in
            isReloading = false
            if let error = error {
                // Chỉ hiển thị cảnh báo nếu có lỗi thực sự xảy ra
                self.alertMessage = "Chưa đồng bộ được: \(error.localizedDescription).\n\nVui lòng bấm nút 'Mở Cài Đặt iPhone' bên dưới để bật quyền cho ứng dụng."
                self.showAlert = true
            } else {
                checkExtensionStatus()
            }
        }
    }
    
    // Mở trực tiếp Cài đặt của iPhone
    private func openPhoneSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
