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
    @State private var messageText = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationSplitView {
            VStack {
                // LINE メッセージセクション
                GroupBox("LINE Messages") {
                    VStack(alignment: .leading, spacing: 10) {
                        // 受信メッセージ一覧
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(lineService.receivedMessages, id: \.id) { message in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(message.text ?? "")
                                            .padding(8)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(8)
                                        Text(Date(timeIntervalSince1970: message.timestamp / 1000), style: .time)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(height: 200)
                        
                        // メッセージ送信
                        HStack {
                            TextField("メッセージを入力", text: $messageText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button("送信") {
                                sendMessage()
                            }
                            .disabled(messageText.isEmpty || Config.LineAPI.groupID.isEmpty)
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
        }
    }

    private func sendMessage() {
        Task {
            do {
                try await lineService.sendMessage(to: Config.LineAPI.groupID, text: messageText)
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
