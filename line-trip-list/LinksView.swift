import SwiftUI

struct LinksView: View {
    @ObservedObject var lineService: LineMessageService
    @EnvironmentObject var nameStore: DisplayNameStore

    var body: some View {
        NavigationStack {
            List {
                if lineService.extractedLinks.isEmpty {
                    Text("共有されたリンクはありません")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(lineService.extractedLinks) { link in
                        HStack {
                            if let preview = link.previewImageURL, let url = URL(string: preview) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView().frame(width:60,height:60)
                                    case .success(let image): image.resizable().scaledToFill().frame(width:60,height:60).clipped()
                                    case .failure: Image(systemName: "photo").frame(width:60,height:60)
                                    @unknown default: EmptyView()
                                    }
                                }
                            } else if link.isImage, let url = URL(string: link.url) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .empty: ProgressView().frame(width:60,height:60)
                                    case .success(let image): image.resizable().scaledToFill().frame(width:60,height:60).clipped()
                                    case .failure: Image(systemName: "photo").frame(width:60,height:60)
                                    @unknown default: EmptyView()
                                    }
                                }
                            } else {
                                Rectangle().fill(Color.clear).frame(width:60,height:60)
                            }

                            VStack(alignment: .leading) {
                                Text(link.url).font(.caption).lineLimit(1).truncationMode(.middle)
                                Text(nameStore.displayName(for: link.sourceUserId, fallback: link.sourceUser)).font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .contextMenu {
                            Button("Copy URL") { UIPasteboard.general.string = link.url }
                        }
                    }
                }
            }
            .navigationTitle("Shared Links")
            .toolbar { Button("Refresh") { Task { await lineService.fetchMessages(); await lineService.validateImageLinks() } } }
        }
    }
}

struct LinksView_Previews: PreviewProvider {
    static var previews: some View {
        LinksView(lineService: LineMessageService())
    }
}
