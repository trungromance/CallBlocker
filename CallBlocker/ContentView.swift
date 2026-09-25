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
                    
                    // Trạng thái cấp quyền trong Cài đặt iPhone (BẤM VÀO ĐỂ MỞ CÀI ĐẶT NGAY)
                    Button(action: openCallBlockingSettings) {
                        HStack {
                            Image(systemName: isExtensionEnabledInSettings ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isExtensionEnabledInSettings ? .green : .orange)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Quyền iOS: \(extensionStatusText)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Text(isExtensionEnabledInSettings ? "Đã sẵn sàng chặn cuộc gọi" : "Chạm vào đây để mở Cài đặt bật quyền")
                                    .font(.caption2)
                                    .foregroundColor(isExtensionEnabledInSettings ? .secondary : .orange)
                            }
                            
                            Spacer()
                            
                            if isReloading {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
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
                
                // MARK: - 4. 2 NÚT MỞ CÀI ĐẶT CHUYÊN BIỆT
                Section(header: Text("TRUY CẬP NHANH CÀI ĐẶT IPHONE").font(.caption).foregroundColor(.gray)) {
                    // Nút 1: Mở Phone / Call Blocking & Identification
                    Button(action: openCallBlockingSettings) {
                        HStack(spacing: 12) {
                            Image(systemName: "phone.badge.checkmark")
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.green)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mở Cài Đặt Chặn Cuộc Gọi")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Cài đặt ➔ Điện thoại ➔ Chặn cuộc gọi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Nút 2: Mở Cài đặt Nhà phát triển / Quản lý thiết bị
                    Button(action: openDeveloperDeviceSettings) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(Color.blue)
                                .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mở Quản Lý Thiết Bị (Trust App)")
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                Text("Cài đặt ➔ Cài đặt chung ➔ VPN & Quản lý thiết bị")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
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
    
    private func syncWithCallKitSilently() {
        isReloading = true
        BlockListManager.shared.reloadExtension { error in
            isReloading = false
            if let error = error {
                self.alertMessage = "Chưa đồng bộ được: \(error.localizedDescription).\n\nVui lòng vào Cài đặt -> Điện thoại -> Chặn & Nhận dạng cuộc gọi để bật ứng dụng."
                self.showAlert = true
            } else {
                checkExtensionStatus()
            }
        }
    }
    
    // Mở Cài đặt Chặn cuộc gọi (Call Blocking)
    private func openCallBlockingSettings() {
        // Thử Deep-link trực tiếp vào trang Điện thoại nếu iOS cho phép, fallback về Cài đặt
        if let url = URL(string: "App-Prefs:root=Phone"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    openStandardSettings()
                }
            }
        } else {
            openStandardSettings()
        }
    }
    
    // Mở Cài đặt Quản lý thiết bị & VPN (Trust Developer Profile)
    private func openDeveloperDeviceSettings() {
        // Thử Deep-link trực tiếp vào Managed Configuration List
        if let url = URL(string: "App-Prefs:root=General&path=ManagedConfigurationList"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    openStandardSettings()
                }
            }
        } else {
            openStandardSettings()
        }
    }
    
    private func openStandardSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
