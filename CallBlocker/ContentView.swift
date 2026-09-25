import SwiftUI
import CallKit

struct ContentView: View {
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MainBlockerView()
                .tabItem {
                    Image(systemName: "shield.fill")
                    Text("Chặn cuộc gọi")
                }
                .tag(0)
            
            HistoryAndLookupView()
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Lịch sử & Tra cứu")
                }
                .tag(1)
        }
        .accentColor(.orange)
    }
}

// MARK: - TAB 1: GIAO DIỆN CHÍNH (WARP STYLE)
struct MainBlockerView: View {
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
                    
                    // MARK: - 1. GIAO DIỆN SWITCH TO CĂN GIỮA (KIỂU WARP)
                    VStack(spacing: 16) {
                        // Tên App
                        Text("Chặn số rác")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(isMasterEnabled ? Color.orange : Color.secondary)
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
                                        ? LinearGradient(colors: [Color.orange, Color.red], startPoint: .leading, endPoint: .trailing)
                                        : LinearGradient(colors: [Color(.systemGray4), Color(.systemGray5)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .frame(width: 130, height: 70)
                                    .shadow(color: isMasterEnabled ? Color.orange.opacity(0.35) : Color.clear, radius: 10, x: 0, y: 5)
                                
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 58, height: 58)
                                    .padding(6)
                                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Mô tả trạng thái
                        Text(isMasterEnabled ? "Đang tự động chặn các cuộc gọi từ đầu số đã thêm" : "Đã tạm dừng bảo vệ và chặn cuộc gọi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 8)
                    
                    // MARK: - 2. KHUNG THÊM ĐẦU SỐ MỚI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("THÊM ĐẦU SỐ CẦN CHẶN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Text("+84")
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                                
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
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                                .background(
                                    newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? Color.gray.opacity(0.3)
                                    : Color.orange
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(newPrefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - 3. DANH SÁCH ĐẦU SỐ BỊ CHẶN
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("DANH SÁCH ĐẦU SỐ BỊ CHẶN (\(rules.count))")
                                .font(.caption)
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
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray)
                                Text("Chưa có đầu số nào. Hãy thêm đầu số ở trên.")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(rules) { rule in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text("\(rule.prefix)*")
                                                    .font(.headline)
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
                    
                    // MARK: - 4. HƯỚNG DẪN CÀI ĐẶT & CẤP QUYỀN
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HƯỚNG DẪN KÍCH HOẠT QUYỀN")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Gợi ý 1: Tin cậy nhà phát triển
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .foregroundColor(.orange)
                                    Text("1. Tin cậy chứng chỉ (Nếu báo Chưa tin cậy)")
                                        .font(.subheadline)
                                }
                                Text("Vào **Cài đặt** ➔ **Cài đặt chung** ➔ **VPN & Quản lý thiết bị** ➔ Chọn tài khoản Apple ID ➔ Nhấn **Tin cậy**.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            // Gợi ý 2: Bật quyền chặn cuộc gọi
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: "phone.badge.checkmark")
                                        .foregroundColor(.green)
                                    Text("2. Kích hoạt chặn cuộc gọi")
                                        .font(.subheadline)
                                }
                                Text("Vào **Cài đặt** ➔ **Điện thoại** ➔ **Chặn & Nhận dạng cuộc gọi** ➔ Bật công tắc **Chặn số rác** sang màu xanh.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
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

// MARK: - TAB 2: LỊCH SỬ & TRA CỨU SỐ ĐIỆN THOẠI
struct HistoryAndLookupView: View {
    @State private var logs: [BlockLogItem] = []
    @State private var testNumber: String = ""
    @State private var checkResultText: String = ""
    @State private var checkResultBlocked: Bool? = nil
    @State private var totalProtectedCount: Int = 0
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - THẺ THỐNG KÊ TỔNG QUAN
                    HStack(spacing: 16) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 38))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tổng số đang bảo vệ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(totalProtectedCount.formatted()) số điện thoại")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    
                    // MARK: - CÔNG CỤ TRA CỨU & KIỂM TRA SỐ
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRA CỨU & KIỂM TRA SỐ ĐIỆN THOẠI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                
                                TextField("Nhập số cần kiểm tra (VD: 0592888999)", text: $testNumber)
                                    .keyboardType(.numberPad)
                                    .onChange(of: testNumber) { _ in
                                        checkResultBlocked = nil
                                        checkResultText = ""
                                    }
                            }
                            .padding(10)
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            
                            Button(action: performNumberCheck) {
                                HStack {
                                    Spacer()
                                    Text("Kiểm Tra Trạng Thái Chặn")
                                        .font(.subheadline)
                                    Spacer()
                                }
                                .padding(.vertical, 10)
                                .background(testNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.3) : Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(testNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            
                            // Kết quả kiểm tra
                            if let isBlocked = checkResultBlocked {
                                HStack(spacing: 10) {
                                    Image(systemName: isBlocked ? "xmark.shield.fill" : "checkmark.shield.fill")
                                        .foregroundColor(isBlocked ? .red : .green)
                                        .font(.title2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(isBlocked ? "SỐ NÀY SẼ BỊ CHẶN" : "SỐ NÀY ĐƯỢC PHÉP GỌI")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(isBlocked ? .red : .green)
                                        
                                        Text(checkResultText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(isBlocked ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    // MARK: - NHẬT KÝ HOẠT ĐỘNG
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("NHẬT KÝ HOẠT ĐỘNG (\(logs.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if !logs.isEmpty {
                                Button("Xoá nhật ký") {
                                    BlockListManager.shared.clearLogs()
                                    loadLogs()
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        if logs.isEmpty {
                            Text("Chưa có lịch sử hoạt động nào.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                                .background(Color(.secondarySystemGroupedBackground))
                                .cornerRadius(14)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(logs) { log in
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.orange)
                                            .font(.subheadline)
                                            .padding(.top, 2)
                                        
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(log.title)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.primary)
                                            
                                            Text(log.detail)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            
                                            Text(log.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // MARK: - GỢI Ý XEM LỊCH SỬ TRÊN IPHONE
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Xem cuộc gọi rác đã bị từ chối")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("Khi có số rác gọi đến, iOS sẽ tự động ngắt kết nối trước khi rung chuông. Bạn có thể xem lại các cuộc gọi này trong ứng dụng **Điện thoại ➔ Gần đây** trên iPhone.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Lịch Sử & Tra Cứu")
            .onAppear {
                loadLogs()
            }
        }
    }
    
    private func loadLogs() {
        self.logs = BlockListManager.shared.getLogs()
        self.totalProtectedCount = BlockListManager.shared.getTotalProtectedNumbersCount()
    }
    
    private func performNumberCheck() {
        let result = BlockListManager.shared.checkNumberBlocked(input: testNumber)
        self.checkResultBlocked = result.isBlocked
        if result.isBlocked, let rule = result.matchedRule {
            self.checkResultText = "Số này khớp với quy tắc chặn: \(rule.prefix)* (\(rule.note.isEmpty ? "Đang bật" : rule.note))"
        } else {
            self.checkResultText = "Số này không nằm trong bất kỳ dải số bị chặn nào."
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
