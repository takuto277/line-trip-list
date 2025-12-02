//
//  MessageTabView.swift
//  line-trip-list
//
//  Created by automated refactor on 2025/12/03.
//

import SwiftUI
import SwiftData

struct MessageTabView: View {
    @Environment(\.modelContext) private var modelContext
    // removed items query - Item list not needed
    @EnvironmentObject var messagesVM: MessagesViewModel
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
                
                // LinkRowView is defined at file scope below to avoid ViewBuilder declaration issues

                GroupBox("LINE Messages") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("受信メッセージ (\(messagesVM.messages.count))")
                                .font(.headline)
                            Spacer()
                            Button("更新") {
                                Task {
                                    if let userId = authService.currentUser?.userId {
                                        await messagesVM.refresh(lineId: userId, into: modelContext)
                                        nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
                                    } else {
                                        await messagesVM.refresh(into: modelContext)
                                        nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
                                    }
                                }
                            }
                            .disabled(messagesVM.isLoading)
                        }
                        
                        // 受信メッセージ一覧
                        if messagesVM.isLoading {
                            ProgressView("読み込み中...")
                                .frame(minHeight: 200)
                        } else if messagesVM.messages.isEmpty {
                            VStack {
                                Text("まだメッセージがありません")
                                    .foregroundColor(.secondary)
                                Text("LINEグループでメッセージを送信してください")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(minHeight: 200)
                        } else {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(messagesVM.messages, id: \.timestamp) { message in
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
                                .padding(.bottom, 20)
                            }
                            .frame(maxHeight: .infinity)
                        }
                        
                        // メッセージ送信
                        HStack {
                            TextField("メッセージを入力", text: $messageText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("送信") {
                                Task {
                                    do {
                                        try await messagesVM.send(text: messageText, to: Config.MessagingAPI.groupID)
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
                    await messagesVM.refresh(lineId: userId, into: modelContext)
                    nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
                } else {
                    await messagesVM.refresh(into: modelContext)
                    nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
                }
            }
        }

        // ログイン・ログアウト時に userId が変わったら再取得
        .onChange(of: authService.currentUser?.userId) { newUserId in
            Task {
                if let id = newUserId {
                    await messagesVM.refresh(lineId: id, into: modelContext)
                    nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
                } else {
                    await messagesVM.refresh(into: modelContext)
                    nameStore.addDiscoveredUserIds(messagesVM.messages.map { $0.userId ?? $0.userName })
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
        // sendMessage moved to MessagesViewModel.send(text:to:)
    }

    private func addItem() {
        // no-op: item list removed
    }

    private func deleteItems(offsets: IndexSet) {
        // no-op: item list removed
    }
}

#Preview {
    MessageTabView()
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
