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
                        syncWithCallKit()
                    }
                    
                    // Trạng thái cấp quyền trong Cài đặt iPhone
                    HStack {
                        Image(systemName: isExtensionEnabledInSettings ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isExtensionEnabledInSettings ? .green : .orange)
                        Text("Quyền iOS: \(extensionStatusText)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
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
                            
                            TextField("Ví dụ: 059 hoặc 059*", text: $newPrefix)
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
                    if isReloading {
                        ProgressView().scaleEffect(0.8)
                    }
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
                                        syncWithCallKit()
                                    }
                                ))
                                .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteRules)
                    }
                }
                
                // MARK: - 4. NÚT ĐỒNG BỘ THỦ CÔNG
                Section {
                    Button(action: syncWithCallKit) {
                        HStack {
                            Spacer()
                            if isReloading {
                                ProgressView()
                                    .padding(.trailing, 6)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Áp Dụng & Đồng Bộ Với iOS")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .disabled(isReloading)
                }
                
                // MARK: - 5. HƯỚNG DẪN KÍCH HOẠT TRÊN IPHONE
                Section(header: Text("HƯỚNG DẪN KÍCH HOẠT QUYỀN TRÊN IPHONE").font(.caption).foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Text("1.")
                                .fontWeight(.bold)
                            Text("Vào **Cài đặt (Settings)** trên iPhone.")
                        }
                        HStack(alignment: .top) {
                            Text("2.")
                                .fontWeight(.bold)
                            Text("Chọn mục **Điện thoại (Phone)**.")
                        }
                        HStack(alignment: .top) {
                            Text("3.")
                                .fontWeight(.bold)
                            Text("Nhấn **Chặn & Nhận dạng cuộc gọi (Call Blocking & Identification)**.")
                        }
                        HStack(alignment: .top) {
                            Text("4.")
                                .fontWeight(.bold)
                            Text("BẬT công tắc của ứng dụng **Chặn số rác**.")
                        }
                    }
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
                Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("Đã hiểu")))
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
        syncWithCallKit()
    }
    
    private func deleteRules(at offsets: IndexSet) {
        BlockListManager.shared.removeRule(at: offsets)
        loadRules()
        syncWithCallKit()
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
                self.extensionStatusText = "Đã kích hoạt trong Cài đặt"
                self.isExtensionEnabledInSettings = true
            case .disabled:
                self.extensionStatusText = "Chưa bật trong Cài đặt Điện thoại"
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
    
    private func syncWithCallKit() {
        isReloading = true
        BlockListManager.shared.reloadExtension { error in
            isReloading = false
            if let error = error {
                self.alertMessage = "Cập nhật thất bại: \(error.localizedDescription).\n\nHãy đảm bảo bạn đã bật ứng dụng trong: Cài đặt -> Điện thoại -> Chặn & Nhận dạng cuộc gọi."
            } else {
                self.alertMessage = "Đã đồng bộ thành công dải số chặn vào hệ thống iOS!"
                checkExtensionStatus()
            }
            self.showAlert = true
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
