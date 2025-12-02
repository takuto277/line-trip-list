import Foundation
import Combine

@MainActor
final class LinksViewModel: ObservableObject {
    @Published private(set) var links: [LineMessageService.LinkItem] = []
    @Published var isLoading: Bool = false

    private let repository: LineMessageService
    private var cancellables = Set<AnyCancellable>()

    init(repository: LineMessageService) {
        self.repository = repository
        self.links = repository.extractedLinks
        self.isLoading = repository.isLoading
        // Keep the view model in sync with repository published values
        repository.$extractedLinks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLinks in
                self?.links = newLinks
            }
            .store(in: &cancellables)

        repository.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.isLoading = loading
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        isLoading = true
        await repository.fetchMessages()
        // repository updates extractedLinks internally
        self.links = repository.extractedLinks
        isLoading = repository.isLoading
        isLoading = false
    }

    // Expose repository operations via ViewModel to maintain encapsulation
    func fetchImageCandidates(for link: LineMessageService.LinkItem, query: String) async -> [String] {
        return await repository.fetchImageCandidates(for: link, query: query)
    }

    func validateImageLinks() async {
        await repository.validateImageLinks()
    }

    func setPreview(for linkID: UUID, url: String?, source: String?) {
        if let idx = links.firstIndex(where: { $0.id == linkID }) {
            var updated = links
            updated[idx].previewImageURL = url
            updated[idx].previewImageSource = source
            links = updated
            repository.extractedLinks = updated
        }
    }
}
