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
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - 1. GIAO DIỆN SWITCH TO CĂN GIỮA (KIỂU CLOUDFLARE WARP)
                    VStack(spacing: 16) {
                        // Tên App kiểu WARP
                        Text("CHẶN SỐ RÁC")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundColor(isMasterEnabled ? Color.orange : Color.gray)
                            .padding(.top, 10)
                        
                        // Nút Switch to lớn nằm chính giữa
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                isMasterEnabled.toggle()
                                BlockListManager.shared.isMasterEnabled = isMasterEnabled
                                syncWithCallKitSilently()
                            }
                        }) {
                            ZStack(alignment: isMasterEnabled ? .trailing : .leading) {
                                Capsule()
                                    .fill(
                                        isMasterEnabled
                                        ? LinearGradient(colors: [Color.orange, Color.red, Color.pink], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: 140, height: 75)
                                    .shadow(color: isMasterEnabled ? Color.red.opacity(0.35) : Color.clear, radius: 12, x: 0, y: 6)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 63, height: 63)
                                    .padding(6)
                                    .shadow(color: Color.black.opacity(0.18), radius: 4, x: 0, y: 2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Chữ trạng thái BẬT / TẮT to rõ ràng ở dưới nút Switch
                        VStack(spacing: 4) {
                            Text(isMasterEnabled ? "BẬT" : "TẮT")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(isMasterEnabled ? Color.red : Color.secondary)
                            
                            Text(isMasterEnabled ? "Đang tự động chặn các cuộc gọi từ đầu số đã thêm" : "Đã tạm dừng bảo vệ và chặn cuộc gọi")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.vertical, 12)
                    
                    // MARK: - 2. KHUNG THÊM ĐẦU SỐ MỚI
                    VStack(alignment: .leading, spacing: 14) {
                        Text("THÊM ĐẦU SỐ CẦN CHẶN")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("+84")
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                    .font(.system(.body, design: .monospaced))
                                
                                TextField("Ví dụ: 059 hoặc 0592*", text: $newPrefix)
                                    .keyboardType(.numberPad)
                                    .padding(8)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            }
                            
                            TextField("Ghi chú (Ví dụ: Spam tài chính, Telesale)", text: $newNote)
                                .padding(8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .font(.footnote)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )
                            
                            Button(action: addPrefix) {
                                HStack {
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                    Text("Thêm Vào Danh Sách Chặn")
                                        .font(.system(size: 16, weight: .bold))
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(
                                    newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray.opacity(0.3)
                                    : Color.blue
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 3. DANH SÁCH ĐẦU SỐ BỊ CHẶN
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DANH SÁCH ĐẦU SỐ BỊ CHẶN (\(rules.count))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if isReloading {
                                ProgressView().scaleEffect(0.8)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        if rules.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "slash.circle")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray)
                                Text("Chưa có đầu số nào. Hãy thêm đầu số ở trên.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 28)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(rules) { rule in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("\(rule.prefix)*")
                                                    .font(.system(.headline, design: .monospaced))
                                                    .foregroundColor(.red)
                                                
                                                Text("(\(rule.totalDigits) chữ số)")
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
                                        
                                        // Nút bật / tắt riêng lẻ
                                        Toggle("", isOn: Binding(
                                            get: { rule.isEnabled },
                                            set: { _ in
                                                BlockListManager.shared.toggleRule(id: rule.id)
                                                loadRules()
                                                syncWithCallKitSilently()
                                            }
                                        ))
                                        .labelsHidden()
                                        
                                        // Nút xoá số
                                        Button(action: {
                                            deleteRule(rule: rule)
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.red.opacity(0.8))
                                                .padding(8)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(14)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarHidden(true)
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
    
    private func deleteRule(rule: BlockPrefixRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            BlockListManager.shared.removeRule(at: IndexSet(integer: index))
            loadRules()
            syncWithCallKitSilently()
        }
    }
    
    private func checkExtensionStatus() {
        BlockListManager.shared.checkExtensionStatus { status, error in
            if let error = error {
                self.extensionStatusText = "Không thể kiểm tra"
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
