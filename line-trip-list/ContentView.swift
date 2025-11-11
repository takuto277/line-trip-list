//
//  ContentView.swift
//  line-trip-list
//
//  Created by 小野拓人 on 2025/10/01.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // removed items query - Item list not needed
    @StateObject private var lineService = LineMessageService()
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var nameStore: DisplayNameStore
    @State private var messageText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationSplitView {
            VStack {
                // Header moved to Settings; keep a small spacer
                Spacer().frame(height: 6)
                
                // LINE メッセージセクション
                // 共有リンクセクション
                GroupBox("Shared Links") {
                    VStack(alignment: .leading, spacing: 8) {
                        if lineService.extractedLinks.isEmpty {
                            Text("共有されたリンクはまだありません")
                                .foregroundColor(.secondary)
                                .frame(height: 60)
                        } else {
                            ForEach(lineService.extractedLinks) { link in
                                LinkRowView(link: link)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

// LinkRowView is defined at file scope below to avoid ViewBuilder declaration issues

                GroupBox("LINE Messages") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("受信メッセージ (\(lineService.receivedMessages.count))")
                                .font(.headline)
                            Spacer()
                            Button("更新") {
                                Task {
                                    if let userId = authService.currentUser?.userId {
                                        print("🔁 Update pressed — using userId: \(userId)")
                                        await lineService.fetchMessages(lineId: userId)
                                        await lineService.persistMessages(into: modelContext)
                                        // add discovered userIds to overrides list if missing
                                        nameStore.addDiscoveredUserIds(lineService.receivedMessages.map { $0.userId })
                                    } else {
                                        print("🔁 Update pressed — no userId, fetching all")
                                        await lineService.fetchMessages()
                                        await lineService.persistMessages(into: modelContext)
                                        nameStore.addDiscoveredUserIds(lineService.receivedMessages.map { $0.userId })
                                    }
                                }
                            }
                            .disabled(lineService.isLoading)
                        }
                        
                        // 受信メッセージ一覧
                        if lineService.isLoading {
                            ProgressView("読み込み中...")
                                .frame(height: 200)
                        } else if lineService.receivedMessages.isEmpty {
                            VStack {
                                Text("まだメッセージがありません")
                                    .foregroundColor(.secondary)
                                Text("LINEグループでメッセージを送信してください")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 200)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(lineService.receivedMessages, id: \.timestamp) { message in
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack {
                                                Text(nameStore.displayName(for: message.userId, fallback: message.userName))
                                                    .font(.caption)
                                                    .bold()
                                                Spacer()
                                                Text(formatTimestamp(message.timestamp))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(message.message)
                                                .padding(8)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(8)
                                        }
                                        .padding(.horizontal, 4)
                                    }
                                }
                            }
                            .frame(height: 200)
                        }
                        
                        // メッセージ送信
                        HStack {
                            TextField("メッセージを入力", text: $messageText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("送信") {
                                sendMessage()
                            }
                            .disabled(messageText.isEmpty || Config.MessagingAPI.groupID.isEmpty)
                        }
                    }
                }
                
                // Items section removed per request
            }
            .padding()
            // toolbar trimmed (no Item controls)
        } detail: {
            Text("Select an item")
        }
        .alert("メッセージ", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            #if DEBUG
            Config.validateConfiguration()
            #endif

            // 起動時にログイン済みならユーザーIDでフィルタして取得
            Task {
                if let userId = authService.currentUser?.userId {
                    await lineService.fetchMessages(lineId: userId)
                    await lineService.persistMessages(into: modelContext)
                } else {
                    await lineService.fetchMessages()
                    await lineService.persistMessages(into: modelContext)
                }
            }
        }

        // ログイン・ログアウト時に userId が変わったら再取得
        .onChange(of: authService.currentUser?.userId) { newUserId in
            Task {
                if let id = newUserId {
                    await lineService.fetchMessages(lineId: id)
                    await lineService.persistMessages(into: modelContext)
                } else {
                    await lineService.fetchMessages()
                    await lineService.persistMessages(into: modelContext)
                }
            }
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func sendMessage() {
        Task {
            do {
                try await lineService.sendMessage(to: Config.MessagingAPI.groupID, text: messageText)
                await MainActor.run {
                    messageText = ""
                    alertMessage = "メッセージを送信しました"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertMessage = "送信に失敗しました: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }

    private func addItem() {
        // no-op: item list removed
    }

    private func deleteItems(offsets: IndexSet) {
        // no-op: item list removed
    }
}

#Preview {
    ContentView()
}

// LinkRowView: extracted to top-level to ease compiler type-checking
struct LinkRowView: View {
    let link: LineMessageService.LinkItem
    @EnvironmentObject var nameStore: DisplayNameStore

    var body: some View {
        HStack {
            if let preview = link.previewImageURL, let pu = URL(string: preview) {
                AsyncImage(url: pu) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo")
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else if link.isImage, let u = URL(string: link.url) {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipped()
                    case .failure:
                        Image(systemName: "photo")
                            .frame(width: 60, height: 60)
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 60, height: 60)
            }

            VStack(alignment: .leading) {
                Text(link.url)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(nameStore.displayName(for: link.sourceUserId, fallback: link.sourceUser))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                if let u = URL(string: link.url) {
                    UIApplication.shared.open(u)
                }
            }) {
                Image(systemName: "safari")
            }
        }
        .contextMenu {
            Button("Copy URL") {
                UIPasteboard.general.string = link.url
            }
        }
    }
}
