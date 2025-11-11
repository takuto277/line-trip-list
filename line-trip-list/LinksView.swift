import SwiftUI

struct LinksView: View {
    @ObservedObject var lineService: LineMessageService
    @EnvironmentObject var nameStore: DisplayNameStore

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
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Shared Links")
            .toolbar { Button("Refresh") { Task { await lineService.fetchMessages(); await lineService.validateImageLinks() } } }
        }
    }

    // Card view for each link
    @ViewBuilder
    private func LinkCard(link: LineMessageService.LinkItem) -> some View {
        VStack(spacing: 8) {
            // top: preview image source or submitter name
            if let src = link.previewImageSource, !src.isEmpty {
                Text(src)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(nameStore.displayName(for: link.sourceUserId, fallback: link.sourceUser))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                            image.resizable().scaledToFit().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo").resizable().scaledToFit().frame(maxWidth: .infinity).aspectRatio(16.0/9.0, contentMode: .fit)
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
