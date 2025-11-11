import SwiftUI

struct LinksView: View {
    @ObservedObject var lineService: LineMessageService
    @EnvironmentObject var nameStore: DisplayNameStore
    @State private var editingLinkID: UUID? = nil
    @State private var editingImageURL: String = ""
    @State private var showEditImageSheet: Bool = false
    @State private var showCandidatePicker: Bool = false
    @State private var candidateImages: [String] = []
    @State private var candidateSearchQuery: String = ""
    @State private var _candidateImages: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                if lineService.extractedLinks.isEmpty {
                    VStack {
                        Text("共有されたリンクはありません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
                            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                                ForEach(lineService.extractedLinks) { link in
                                    LinkCard(link: link)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.secondarySystemBackground)))
                                        .onTapGesture {
                                            if let u = URL(string: link.url) {
                                                UIApplication.shared.open(u)
                                            }
                                        }
                                        .contextMenu {
                                            Button("Copy URL") { UIPasteboard.general.string = link.url }
                                            Button("画像を変更") {
                                                // open candidate picker
                                                editingLinkID = link.id
                                                Task {
                                                    let candidates = await lineService.fetchImageCandidates(for: link, query: link.previewImageSource ?? "")
                                                    await MainActor.run {
                                                        self._candidateImages = candidates
                                                        self.showCandidatePicker = true
                                                    }
                                                }
                                            }
                                        }
                                }
                            }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Shared Links")
            .toolbar { Button("Refresh") { Task { await lineService.fetchMessages(); await lineService.validateImageLinks() } } }
            .sheet(isPresented: $showEditImageSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("新しい画像 URL")) {
                            TextField("https://...", text: $editingImageURL)
                                .keyboardType(.URL)
                                .textContentType(.URL)
                        }
                    }
                    .navigationTitle("画像を変更")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル") { showEditImageSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                // apply change to the selected link
                                if let id = editingLinkID, let idx = lineService.extractedLinks.firstIndex(where: { $0.id == id }) {
                                    var updated = lineService.extractedLinks
                                    let newUrl = editingImageURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                    updated[idx].previewImageURL = newUrl.isEmpty ? nil : newUrl
                                    updated[idx].previewImageSource = newUrl.isEmpty ? updated[idx].previewImageSource : "手動"
                                    lineService.extractedLinks = updated
                                }
                                showEditImageSheet = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCandidatePicker) {
                NavigationStack {
                    VStack {
                        HStack {
                            TextField("検索語を入力", text: $candidateSearchQuery)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("検索") {
                                Task {
                                    if let id = editingLinkID, let link = lineService.extractedLinks.first(where: { $0.id == id }) {
                                        let q = candidateSearchQuery.isEmpty ? (link.previewImageSource ?? "") : candidateSearchQuery
                                        let candidates = await lineService.fetchImageCandidates(for: link, query: q)
                                        await MainActor.run {
                                            self.candidateImages = candidates
                                        }
                                    }
                                }
                            }
                        }
                        .padding()

                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                ForEach(candidateImages, id: \ .self) { imgUrl in
                                    VStack {
                                        if let u = URL(string: imgUrl) {
                                            AsyncImage(url: u) { phase in
                                                switch phase {
                                                case .empty:
                                                    ProgressView().frame(height: 80)
                                                case .success(let image):
                                                    image.resizable().scaledToFill().frame(height: 120).clipped()
                                                case .failure:
                                                    Image(systemName: "photo").frame(height: 80)
                                                @unknown default:
                                                    EmptyView()
                                                }
                                            }
                                        }
                                        Button("選択") {
                                            if let id = editingLinkID, let idx = lineService.extractedLinks.firstIndex(where: { $0.id == id }) {
                                                var updated = lineService.extractedLinks
                                                updated[idx].previewImageURL = imgUrl
                                                updated[idx].previewImageSource = candidateSearchQuery.isEmpty ? updated[idx].previewImageSource : candidateSearchQuery
                                                lineService.extractedLinks = updated
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
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("閉じる") { showCandidatePicker = false }
                        }
                    }
                }
            }
        }
    }

    // Card view for each link
    @ViewBuilder
    private func LinkCard(link: LineMessageService.LinkItem) -> some View {
        VStack(spacing: 8) {
            // top: title (preview source or submitter)
            let titleText = (link.previewImageSource?.isEmpty == false) ? link.previewImageSource! : link.sourceUser
            Text(titleText)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // middle: large image (or placeholder)
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
                                .aspectRatio(16.0/9.0, contentMode: .fit)
                                .onLongPressGesture {
                                    // open change image sheet
                                    editingLinkID = link.id
                                    editingImageURL = link.previewImageURL ?? ""
                                    showEditImageSheet = true
                                }
                                .contextMenu {
                                    Button("Copy URL") { UIPasteboard.general.string = link.url }
                                    Button("画像を変更") {
                                        editingLinkID = link.id
                                        editingImageURL = link.previewImageURL ?? ""
                                        showEditImageSheet = true
                                    }
                                }
                        case .failure:
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(16.0/9.0, contentMode: .fit)
                                .onLongPressGesture {
                                    editingLinkID = link.id
                                    editingImageURL = link.previewImageURL ?? ""
                                    showEditImageSheet = true
                                }
                                .contextMenu {
                                    Button("Copy URL") { UIPasteboard.general.string = link.url }
                                    Button("画像を変更") {
                                        editingLinkID = link.id
                                        editingImageURL = link.previewImageURL ?? ""
                                        showEditImageSheet = true
                                    }
                                }
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
                            image.resizable().scaledToFit().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                                .onLongPressGesture {
                                    editingLinkID = link.id
                                    editingImageURL = link.previewImageURL ?? link.url
                                    showEditImageSheet = true
                                }
                                .contextMenu {
                                    Button("Copy URL") { UIPasteboard.general.string = link.url }
                                    Button("画像を変更") {
                                        editingLinkID = link.id
                                        editingImageURL = link.previewImageURL ?? link.url
                                        showEditImageSheet = true
                                    }
                                }
                        case .failure:
                            Image(systemName: "photo").resizable().scaledToFit().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                                .onLongPressGesture {
                                    editingLinkID = link.id
                                    editingImageURL = link.previewImageURL ?? ""
                                    showEditImageSheet = true
                                }
                                .contextMenu {
                                    Button("Copy URL") { UIPasteboard.general.string = link.url }
                                    Button("画像を変更") {
                                        editingLinkID = link.id
                                        editingImageURL = link.previewImageURL ?? ""
                                        showEditImageSheet = true
                                    }
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Rectangle().fill(Color(UIColor.systemGray5)).frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                }
            }

            // bottom: URL limited to 2 lines
            Text(link.url)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LinksView_Previews: PreviewProvider {
    static var previews: some View {
        LinksView(lineService: LineMessageService())
    }
}
