
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct LinksView: View {
    @StateObject private var vm: LinksViewModel
    @EnvironmentObject var nameStore: DisplayNameStore
    @Environment(\.openURL) private var openURL
    
    @State private var editingLinkID: UUID? = nil
    @State private var editingImageURL: String = ""
    @State private var showEditImageSheet: Bool = false
    @State private var showCandidatePicker: Bool = false
    @State private var candidateImages: [String] = []
    @State private var candidateSearchQuery: String = ""
    
    init(repository: LineMessageService) {
        _vm = StateObject(wrappedValue: LinksViewModel(repository: repository))
    }
    
        var body: some View {
            NavigationStack {
                ScrollView {
                    if vm.links.isEmpty {
                        VStack {
                            Text("共有されたリンクはありません")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        gridView
                    }
                }
                .navigationTitle("Shared Links")
                .toolbar { Button("Refresh") { Task { await vm.refresh(); await vm.validateImageLinks() } } }
                .sheet(isPresented: $showEditImageSheet) { editImageSheet }
                .sheet(isPresented: $showCandidatePicker) { candidatePickerSheet }
                .onAppear {
                    Task { await vm.refresh() }
                }
            }
        }

        // extracted subviews to reduce type-check complexity
        private var gridView: some View {
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            let bgColor: Color = {
#if canImport(UIKit)
                return Color(UIColor.secondarySystemBackground)
#else
                return Color.secondary.opacity(0.1)
#endif
            }()

            return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(vm.links) { link in
                    LinkCardView(link: link)
                        .background(RoundedRectangle(cornerRadius: 8).fill(bgColor))
                        .onTapGesture {
                            if let u = URL(string: link.url) { openURL(u) }
                        }
                        .contextMenu {
                            Button("Copy URL") { copyToPasteboard(link.url) }
                            Button("画像を変更") {
                                editingLinkID = link.id
                                Task {
                                    let candidates = await vm.fetchImageCandidates(for: link, query: link.previewImageSource ?? "")
                                    await MainActor.run {
                                        self.candidateImages = candidates
                                        self.showCandidatePicker = true
                                    }
                                }
                            }
                        }
                }
            }
            .padding(.horizontal)
        }

        private var editImageSheet: some View {
            NavigationStack {
                Form {
                    Section(header: Text("新しい画像 URL")) {
                        TextField("https://...", text: $editingImageURL)
#if canImport(UIKit)
                            .keyboardType(.URL)
                            .textContentType(.URL)
#endif
                    }
                }
                .navigationTitle("画像を変更")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { showEditImageSheet = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            if let id = editingLinkID {
                                let newUrl = editingImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                vm.setPreview(for: id, url: newUrl.isEmpty ? nil : newUrl, source: newUrl.isEmpty ? nil : "手動")
                            }
                            showEditImageSheet = false
                        }
                    }
                }
            }
        }

        private var candidatePickerSheet: some View {
            NavigationStack {
                VStack {
                    HStack {
                        TextField("検索語を入力", text: $candidateSearchQuery)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("検索") {
                            Task {
                                if let id = editingLinkID, let link = vm.links.first(where: { $0.id == id }) {
                                            let q = candidateSearchQuery.isEmpty ? (link.previewImageSource ?? "") : candidateSearchQuery
                                            let candidates = await vm.fetchImageCandidates(for: link, query: q)
                                            await MainActor.run { self.candidateImages = candidates }
                                }
                            }
                        }
                    }
                    .padding()

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(candidateImages, id: \.self) { imgUrl in
                                VStack {
                                    if let u = URL(string: imgUrl) {
                                        AsyncImage(url: u) { phase in
                                            switch phase {
                                            case .empty: ProgressView().frame(height: 80)
                                            case .success(let image): image.resizable().scaledToFill().frame(height: 120).clipped()
                                            case .failure: Image(systemName: "photo").frame(height: 80)
                                            @unknown default: EmptyView()
                                            }
                                        }
                                    }
                                    Button("選択") {
                                            if let id = editingLinkID {
                                                vm.setPreview(for: id, url: imgUrl, source: candidateSearchQuery.isEmpty ? nil : candidateSearchQuery)
                                            }
                                        showCandidatePicker = false
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
                .navigationTitle("画像候補を選択")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showCandidatePicker = false } } }
            }
        }
}

private struct LinkCardView: View {
    let link: LineMessageService.LinkItem
    
    var body: some View {
        VStack(spacing: 8) {
            let titleText = (link.previewImageSource?.isEmpty == false) ? link.previewImageSource! : link.sourceUser
            Text(titleText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            ZStack {
                if let preview = link.previewImageURL, let url = URL(string: preview) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16.0/9.0, contentMode: .fit)
                        case .success(let image):
                            image.resizable().scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 120)
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16.0/9.0, contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else if link.isImage, let url = URL(string: link.url) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                        case .success(let image):
                            image.resizable().scaledToFit().frame(maxWidth: .infinity).frame(height: 120)
                        case .failure:
                            Image(systemName: "photo").resizable().scaledToFit().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    } else {
#if canImport(UIKit)
                        Rectangle().fill(Color(UIColor.systemGray5)).frame(maxWidth: .infinity).frame(height: 120)
#else
                        Rectangle().fill(Color.gray.opacity(0.2)).frame(maxWidth: .infinity).frame(height: 120)
#endif
                    }
            }
            
            Text(link.url)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(6)
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .top)
    }
}

struct LinksView_Previews: PreviewProvider {
    static var previews: some View {
        LinksView(repository: LineMessageService())
            .environmentObject(DisplayNameStore())
    }
}

// Helper to copy text to clipboard in UIKit; no-op on other platforms
private func copyToPasteboard(_ text: String) {
#if canImport(UIKit)
    UIPasteboard.general.string = text
#else
    // nothing
#endif
}
