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
    @Query private var items: [Item]
    @StateObject private var lineService = LineMessageService()
    @EnvironmentObject var authService: AuthenticationService
    @State private var messageText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationSplitView {
            VStack {
                // ユーザー情報ヘッダー
                if let user = authService.currentUser {
                    HStack {
                        AsyncImage(url: URL(string: user.pictureUrl ?? "")) { image in
                            image.resizable()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        
                        VStack(alignment: .leading) {
                            Text(user.displayName)
                                .font(.headline)
                            Text(user.userId)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("ログアウト") {
                            authService.logout()
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                
                // LINE メッセージセクション
                GroupBox("LINE Messages") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("受信メッセージ (\(lineService.receivedMessages.count))")
                                .font(.headline)
                            Spacer()
                            Button("更新") {
                                Task {
                                    if let userId = authService.currentUser?.userId {
                                        await lineService.fetchMessages(lineId: userId)
                                    } else {
                                        await lineService.fetchMessages()
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
                                                Text(message.userName)
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
                
                // 既存のアイテムリスト
                GroupBox("Items") {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                            } label: {
                                Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
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
                } else {
                    await lineService.fetchMessages()
                }
            }
        }

        // ログイン・ログアウト時に userId が変わったら再取得
        .onChange(of: authService.currentUser?.userId) { newUserId in
            Task {
                if let id = newUserId {
                    await lineService.fetchMessages(lineId: id)
                } else {
                    await lineService.fetchMessages()
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
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
