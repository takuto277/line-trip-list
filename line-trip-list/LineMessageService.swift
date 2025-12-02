import Foundation
import SwiftData
import Combine

// LINEメッセージの構造体
struct LineMessage: Codable {
    // id は API により無い場合があるため Optional にする
    let id: Int?
    let groupId: String?  // group_id から変更
    let userId: String?   // user_id から変更
    let message: String
    let userName: String  // user_name から変更
    let timestamp: Int64
    let createdAt: String? // created_at から変更（Optional）
    
    // API レスポンス用の CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id" 
        case message
        case userName = "user_name"
        case timestamp
        case createdAt = "created_at"
    }
}

// API レスポンス用の構造体
struct MessagesResponse: Codable {
    // messages が null になる場合があるため Optional にする
    let messages: [LineMessage]?
    let count: Int?
}

// LINE Webhook受信用のサービス
class LineMessageService: ObservableObject, MessageRepository {
    @Published var receivedMessages: [LineMessage] = []
    // 抽出したリンクの一覧
    @Published var extractedLinks: [LinkItem] = []
    @Published var isConnected = false
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    // API の base URL を vercel のデプロイ先に変更
    private let baseURL = "https://line-trip-list-api.vercel.app/api"
    
    init() {
        fetchMessages() // 起動時にメッセージを取得
    }

    // Persist fetched messages into SwiftData ModelContext
    func persistMessages(into context: ModelContext) async {
        await MainActor.run {
            // convert and save using Persistence helper
            Persistence.saveMessageDTOs(self.receivedMessages, into: context )
        }
    }
    
    // メッセージを取得
    // lineId: 任意。指定するとその user_id に一致するメッセージのみ取得する
    func fetchMessages(lineId: String? = nil) async {
        await MainActor.run {
            isLoading = true
        }
        var urlString = "\(baseURL)/messages"
        if let lineId = lineId, !lineId.isEmpty {
            // percent-encode
            if let encoded = lineId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?line_id=\(encoded)"
            } else {
                urlString += "?line_id=\(lineId)"
            }
        }

        guard let url = URL(string: urlString) else {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        do {
            print("🔎 Fetching messages from URL: \(url.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: url)

            if let str = String(data: data, encoding: .utf8) {
                print("📥 Raw response: \(str)")
            } else {
                print("📥 Raw response: <binary>")
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                
                let messagesResponse = try JSONDecoder().decode(MessagesResponse.self, from: data)

                let decodedMessages = messagesResponse.messages ?? []

                await MainActor.run {
                    self.receivedMessages = decodedMessages.sorted { $0.timestamp > $1.timestamp }
                    // メッセージからリンクを抽出
                    self.extractedLinks = Self.extractLinks(from: self.receivedMessages)
                    self.isLoading = false
                }
                // extractedLinks の Content-Type 検証（並列）
                Task {
                    await self.validateImageLinks()
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("❌ Error fetching messages: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // メッセージ内の URL を抽出するヘルパー
    struct LinkItem: Identifiable, Codable {
        let id = UUID()
        let url: String
        let sourceUser: String
        let sourceUserId: String?
        let timestamp: Int64
        var isImage: Bool = false
        var previewImageURL: String? = nil
        // optional human-readable name used to obtain the preview (e.g. place query, "og:image", "map")
        var previewImageSource: String? = nil
    }

    static func extractLinks(from messages: [LineMessage]) -> [LinkItem] {
        var items: [LinkItem] = []
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        for msg in messages {
            if let linkDetector = detector {
                let text = msg.message
                let matches = linkDetector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
                for m in matches {
                        if let range = Range(m.range, in: text), let url = URL(string: String(text[range])) {
                        var item = LinkItem(url: url.absoluteString, sourceUser: msg.userName, sourceUserId: msg.userId, timestamp: msg.timestamp)
                        // 簡易判定: 拡張子が画像系なら isImage を true にする
                        let ext = url.pathExtension.lowercased()
                        if !ext.isEmpty {
                            let imageExts: Set<String> = ["png","jpg","jpeg","gif","webp","bmp","heic","heif"]
                            if imageExts.contains(ext) {
                                item.isImage = true
                            }
                        }
                        // debug
                        print("🔗 Detected link: \(item.url) (isImage initial: \(item.isImage)) from user: \(item.sourceUser)")
                        items.append(item)
                    }
                }
            }
        }
        return items
    }

    // 抽出後に各 URL の Content-Type を HEAD リクエストで確認し、画像なら isImage を true にする
    func validateImageLinks() async {
        var updated = self.extractedLinks
        for (idx, link) in updated.enumerated() {
            if link.isImage { continue }
            guard let url = URL(string: link.url) else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 5
            do {
                let (_, resp) = try await URLSession.shared.data(for: req)
                if let http = resp as? HTTPURLResponse, let ct = http.value(forHTTPHeaderField: "Content-Type") {
                    if ct.starts(with: "image/") {
                        await MainActor.run {
                            updated[idx].isImage = true
                            self.extractedLinks = updated
                        }
                        print("🖼️ HEAD indicates image for \(link.url) — Content-Type: \(ct)")
                    } else {
                        print("ℹ️ HEAD Content-Type for \(link.url): \(ct)")
                    }
                }
            } catch {
                print("⚠️ HEAD request failed for \(link.url): \(error)")
                // HEAD が弾かれることはある。何もしない。
            }
        }
        // HEAD 検証後、OG画像を取得（最大 N 件）
        Task {
            await fetchPreviewImages(maxFetch: 6)
        }
    }

    // ページを GET して og:image / twitter:image を抽出する（クライアント側で完結）
    func fetchPreviewImages(maxFetch: Int = 6) async {
        var updated = self.extractedLinks
        var fetched = 0
        for (idx, link) in updated.enumerated() {
            if fetched >= maxFetch { break }
            if link.previewImageURL != nil || link.isImage { continue }
            guard let url = URL(string: link.url) else { continue }
            print("🌐 GET page to look for OG image: \(url.absoluteString)")
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 6
            req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
            do {
                let (data, resp) = try await URLSession.shared.data(for: req)
                guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { continue }
                let finalURL = resp.url ?? url
                if let html = String(data: data, encoding: .utf8) {
                    // try to find og:image or twitter:image
                    if let og = Self.extractMetaContent(from: html, property: "og:image") {
                        // prefer og:site_name -> og:title -> host (no wrapper text)
                        let siteName = Self.extractMetaContent(from: html, property: "og:site_name")
                        let pageTitle = Self.extractMetaContent(from: html, property: "og:title") ?? Self.matchFirst(html: html, pattern: "<title[^>]*>([\\s\\S]*?)<\\/title>")
                        let host = finalURL.host ?? URL(string: link.url)?.host
                        let label = siteName ?? pageTitle ?? host ?? ""
                        let displayLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                        await MainActor.run {
                            updated[idx].previewImageURL = og
                            updated[idx].previewImageSource = displayLabel
                            self.extractedLinks = updated
                        }
                        print("✅ Found og:image for \(link.url): \(og) (label: \(displayLabel))")
                        fetched += 1
                        continue
                    } else {
                        print("ℹ️ No og:image found in HTML for \(link.url)")
                    }
                    if let tw = Self.extractMetaContent(from: html, name: "twitter:image") {
                        // prefer siteName -> pageTitle -> host (no wrapper)
                        let siteName = Self.extractMetaContent(from: html, property: "og:site_name")
                        let pageTitle = Self.extractMetaContent(from: html, property: "og:title") ?? Self.matchFirst(html: html, pattern: "<title[^>]*>([\\s\\S]*?)<\\/title>")
                        let host = finalURL.host ?? URL(string: link.url)?.host
                        let label = siteName ?? pageTitle ?? host ?? ""
                        let displayLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                        await MainActor.run {
                            updated[idx].previewImageURL = tw
                            updated[idx].previewImageSource = displayLabel
                            self.extractedLinks = updated
                        }
                        print("✅ Found twitter:image for \(link.url): \(tw) (label: \(displayLabel))")
                        fetched += 1
                        continue
                    }
                    // OG が見つからなければ、リダイレクト先URLに座標が含まれるかを試す
                    let finalStr = finalURL.absoluteString
                    if let (lat, lon) = Self.extractCoordinates(from: finalStr) {
                        // OpenStreetMap の静的マップを利用
                        let sm = "https://staticmap.openstreetmap.de/staticmap.php?center=\(lat),\(lon)&zoom=15&size=600x300&markers=\(lat),\(lon),red-pushpin"
                        // default simple label for coordinate-only map
                        let label = String(format: "地図 %.5f,%.5f", lat, lon)
                        await MainActor.run {
                            updated[idx].previewImageURL = sm
                            updated[idx].previewImageSource = label
                            self.extractedLinks = updated
                        }
                        print("🗺️ Generated static map preview for \(link.url) -> \(sm) (label: \(label))")
                        fetched += 1
                        continue
                    } else {
                        print("🔎 No coordinates found in final URL: \(finalStr)")
                        // フォールバック: URL に q= があれば住所としてデコードし、Nominatim でジオコーディングを試みる
                        if let addr = Self.extractQueryParam(from: finalStr, name: "q"), !addr.isEmpty {
                            let decoded = addr.removingPercentEncoding ?? addr
                            print("🔎 Found q= param, trying geocode: \(decoded)")
                                if let (glat, glon) = try? await Self.geocodeAddressWithNominatim(address: decoded) {
                                let sm = "https://staticmap.openstreetmap.de/staticmap.php?center=\(glat),\(glon)&zoom=15&size=600x300&markers=\(glat),\(glon),red-pushpin"
                                let placeName = Self.formatPlaceDisplayName(decoded)
                                await MainActor.run {
                                    updated[idx].previewImageURL = sm
                                    updated[idx].previewImageSource = placeName
                                    self.extractedLinks = updated
                                }
                                print("🗺️ Generated static map via geocoding for \(link.url) -> \(sm) (label: \(placeName))")
                                fetched += 1
                                continue
                            } else {
                                print("⚠️ Nominatim geocode failed for: \(decoded)")
                                // フォールバック: Search image via server-side Google CSE
                                let placeQuery = Self.extractPlaceTerm(from: decoded)
                                print("🔎 Falling back to image search for: \(placeQuery)")
                                if let imageUrl = try? await Self.searchImageForPlace(placeQuery, baseURL: self.baseURL) {
                                    if !imageUrl.isEmpty {
                                        let placeName = Self.formatPlaceDisplayName(placeQuery)
                                        await MainActor.run {
                                            updated[idx].previewImageURL = imageUrl
                                            updated[idx].previewImageSource = placeName
                                            self.extractedLinks = updated
                                        }
                                        print("🖼️ Got image from search for \(placeQuery): \(imageUrl) (label: \(placeName))")
                                        fetched += 1
                                        continue
                                    } else {
                                        print("ℹ️ Image search returned empty for \(placeQuery)")
                                    }
                                } else {
                                    print("⚠️ Image search request failed for \(placeQuery)")
                                }
                            }
                        }
                    }
                }
            } catch {
                print("⚠️ GET page failed for \(link.url): \(error)")
                // ignore failures
            }
        }
    }

    // Fetch up to `max` image candidates for a given LinkItem.
    // Strategy: GET the page, extract og:image and <img src=> URLs (absolute), dedupe and return up to max.
    // If a query is provided and candidates are few, call server-side searchImageForPlace(query) to add a candidate.
    func fetchImageCandidates(for link: LinkItem, query: String? = nil, max: Int = 4) async -> [String] {
        var candidates: [String] = []
        guard let pageURL = URL(string: link.url) else { return candidates }
        var req = URLRequest(url: pageURL)
        req.httpMethod = "GET"
        req.timeoutInterval = 6
        req.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return candidates }
            guard let html = String(data: data, encoding: .utf8) else { return candidates }
            // 1) og:image and twitter:image
            if let og = Self.extractMetaContent(from: html, property: "og:image") {
                if let abs = Self.absoluteUrl(from: og, base: pageURL) { candidates.append(abs) }
            }
            if let tw = Self.extractMetaContent(from: html, name: "twitter:image") {
                if let abs = Self.absoluteUrl(from: tw, base: pageURL) { candidates.append(abs) }
            }
            // 2) all <img src=> entries (simplified regex)
            let imgPattern = "<img[^>]+src=[\"']([^\"']+)[\"'][^>]*>"
            if let regex = try? NSRegularExpression(pattern: imgPattern, options: [.caseInsensitive]) {
                let ns = html as NSString
                let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
                for m in matches {
                    if m.numberOfRanges >= 2 {
                        let raw = ns.substring(with: m.range(at: 1))
                        if let abs = Self.absoluteUrl(from: raw, base: pageURL) {
                            candidates.append(abs)
                        }
                    }
                }
            }
        } catch {
            print("⚠️ fetchImageCandidates GET failed for \(link.url): \(error)")
        }

        // dedupe while preserving order
        var seen = Set<String>()
        let deduped = candidates.filter { url in
            if seen.contains(url) { return false }
            seen.insert(url); return true
        }
        var result = Array(deduped.prefix(max))

        // if not enough candidates and query provided, try server-side image search
        if result.count < max, let q = query, !q.isEmpty {
            if let imageUrl = try? await Self.searchImageForPlace(q, baseURL: self.baseURL), !imageUrl.isEmpty {
                if !result.contains(imageUrl) {
                    result.append(imageUrl)
                }
            }
        }

        return Array(result.prefix(max))
    }

    // Convert possibly relative URL to absolute using base page URL
    static func absoluteUrl(from raw: String, base: URL) -> String? {
        if let u = URL(string: raw), u.scheme != nil { return u.absoluteString }
        // handle protocol-relative URLs
        if raw.hasPrefix("//"), let u = URL(string: base.scheme! + ":" + raw) { return u.absoluteString }
        // relative path
        if let u = URL(string: raw, relativeTo: base)?.absoluteURL { return u.absoluteString }
        return nil
    }

    // URL から指定クエリパラメータの値を取り出す（簡易）
    static func extractQueryParam(from urlString: String, name: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false), let items = comps.queryItems {
            return items.first(where: { $0.name == name })?.value
        }
        // fallback: search manually
        if let range = urlString.range(of: "[?&]" + name + "=", options: .regularExpression) {
            let after = urlString[range.upperBound...]
            if let end = after.firstIndex(where: { $0 == "&" }) {
                return String(after[..<end])
            }
            return String(after)
        }
        return nil
    }

    // Nominatim を使って住所をジオコーディングする（簡易）：1件だけ返す。注意：rate limit と利用規約に注意。
    static func geocodeAddressWithNominatim(address: String) async throws -> (Double, Double)? {
        // normalize Japanese address: remove '〒', convert fullwidth hyphen to ASCII, collapse spaces
        var norm = address
        norm = norm.replacingOccurrences(of: "〒", with: "")
        norm = norm.replacingOccurrences(of: "−", with: "-") // fullwidth minus
        // replace multiple whitespace with single space
        norm = norm.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        // trim
        norm = norm.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let q = norm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        // prefer Japan results and Japanese language
        var urlStr = "https://nominatim.openstreetmap.org/search?format=json&limit=1&countrycodes=jp&accept-language=ja&q=\(q)"
        print("🔎 Nominatim request URL: \(urlStr)")
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        // Nominatim の利用規約に基づき User-Agent を付与
        req.setValue("line-trip-list/1.0 (your-email@example.com)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let body = String(data: data, encoding: .utf8) {
            print("🔎 Nominatim response body: \(body.prefix(1000))")
        }
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        // parse JSON array
        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], let first = arr.first {
            if let latS = first["lat"] as? String, let lonS = first["lon"] as? String, let lat = Double(latS), let lon = Double(lonS) {
                return (lat, lon)
            }
        }

        // retry once without countrycodes (looser), in case the formatted address is not standard
        let altQ = q
        urlStr = "https://nominatim.openstreetmap.org/search?format=json&limit=1&accept-language=ja&q=\(altQ)"
        print("🔁 Nominatim retry URL: \(urlStr)")
        guard let url2 = URL(string: urlStr) else { return nil }
        var req2 = URLRequest(url: url2)
        req2.httpMethod = "GET"
        req2.setValue("line-trip-list/1.0 (your-email@example.com)", forHTTPHeaderField: "User-Agent")
        req2.timeoutInterval = 8
        let (data2, resp2) = try await URLSession.shared.data(for: req2)
        if let body2 = String(data: data2, encoding: .utf8) {
            print("🔁 Nominatim response body: \(body2.prefix(1000))")
        }
        guard let http2 = resp2 as? HTTPURLResponse, http2.statusCode == 200 else { return nil }
        if let arr2 = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]], let first2 = arr2.first {
            if let latS = first2["lat"] as? String, let lonS = first2["lon"] as? String, let lat = Double(latS), let lon = Double(lonS) {
                return (lat, lon)
            }
        }
        return nil
    }

    // URL 文字列から緯度経度を抽出する (Google Maps 系の様々な形式に対応)
    static func extractCoordinates(from urlString: String) -> (Double, Double)? {
        // patterns: @lat,lon,zoom  or q=lat,lon  or ll=lat,lon  or /place/.../@lat,lon,zoom
        let patterns = [
            #"@([0-9+\-\.]+),([0-9+\-\.]+),"#,
            #"[?&]q=([0-9+\-\.]+),([0-9+\-\.]+)"#,
            #"[?&]ll=([0-9+\-\.]+),([0-9+\-\.]+)"#,
            #"/@([0-9+\-\.]+),([0-9+\-\.]+),"#
        ]

        for pat in patterns {
            if let (latS, lonS) = matchTwoGroups(input: urlString, pattern: pat) {
                if let lat = Double(latS), let lon = Double(lonS) {
                    return (lat, lon)
                }
            }
        }
        return nil
    }

    // 簡易的に住所から検索語句を抽出（郵便番号や記号を取り除き主要な地名だけを返す）
    static func extractPlaceTerm(from address: String) -> String {
        var s = address
        // remove postal mark and numbers like 〒 and digits in common formats
        s = s.replacingOccurrences(of: "〒", with: "")
        // replace fullwidth minus
        s = s.replacingOccurrences(of: "−", with: "-")
        // remove postal codes like 358-0014 or 〒3580014
        s = s.replacingOccurrences(of: "[0-9]{3}-?[0-9]{4}", with: "", options: .regularExpression)
    // remove extra symbols (plus and ideographic space U+3000)
    s = s.replacingOccurrences(of: "[+\u{3000}]+", with: " ", options: .regularExpression)
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    // take first 3 to 4 tokens — split using CharacterSet to avoid Character/String mismatches
    let parts = s.components(separatedBy: CharacterSet(charactersIn: " ,")).filter { !$0.isEmpty }
    let take = parts.prefix(4)
    return take.joined(separator: " ")
    }

    // Simplify place/address strings for display: remove postal codes and leading numeric tokens
    static func formatPlaceDisplayName(_ raw: String) -> String {
        var s = raw
        // remove postal mark and postal codes
        s = s.replacingOccurrences(of: "〒", with: "")
        s = s.replacingOccurrences(of: "[0-9]{3}-?[0-9]{4}", with: "", options: .regularExpression)
        // if string contains parentheses or commas, take main part before them
        if let idx = s.firstIndex(of: "(") { s = String(s[..<idx]) }
        if let idx2 = s.firstIndex(of: ",") { s = String(s[..<idx2]) }
        // remove extraneous whitespace and tokens like "住所:"
        s = s.replacingOccurrences(of: "住所", with: "")
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // split by spaces and punctuation, prefer the last 2-3 tokens which often contain place name
        let tokens = s.components(separatedBy: CharacterSet(charactersIn: " /,、　"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if tokens.isEmpty { return s }
        // if last token is numbers, drop it
        let tail = tokens.suffix(3)
        // prefer tokens that are not pure digits
        let filtered = tail.filter { token in
            return token.range(of: "^[0-9]+$", options: .regularExpression) == nil
        }
        let result = filtered.isEmpty ? String(tail.joined(separator: " ")) : String(filtered.joined(separator: " "))
        return result
    }

    // Call server-side image search endpoint and return first image URL (or nil)
    static func searchImageForPlace(_ place: String, baseURL: String) async throws -> String? {
        guard let q = place.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let urlStr = "\(baseURL)/search_image?q=\(q)"
        guard let url = URL(string: urlStr) else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 8
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let imageUrl = obj["imageUrl"] as? String {
            return imageUrl
        }
        return nil
    }

    static func matchTwoGroups(input: String, pattern: String) -> (String, String)? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let ns = input as NSString
            if let m = regex.firstMatch(in: input, options: [], range: NSRange(location: 0, length: ns.length)) {
                if m.numberOfRanges >= 3 {
                    let a = ns.substring(with: m.range(at: 1))
                    let b = ns.substring(with: m.range(at: 2))
                    return (a, b)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    // HTML から meta[property="..."] の content を抽出するユーティリティ
    static func extractMetaContent(from html: String, property: String) -> String? {
        // property 属性版
        let pattern = "<meta[^>]+property=[\"']" + NSRegularExpression.escapedPattern(for: property) + "[\"'][^>]+content=[\"']([^\"']+)[\"'][^>]*>"
        if let v = matchFirst(html: html, pattern: pattern) { return v }
        return nil
    }

    static func extractMetaContent(from html: String, name: String) -> String? {
        // name 属性版
        let pattern = "<meta[^>]+name=[\"']" + NSRegularExpression.escapedPattern(for: name) + "[\"'][^>]+content=[\"']([^\"']+)[\"'][^>]*>"
        if let v = matchFirst(html: html, pattern: pattern) { return v }
        return nil
    }

    static func matchFirst(html: String, pattern: String) -> String? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let ns = html as NSString
            if let m = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: ns.length)) {
                if m.numberOfRanges >= 2 {
                    let r = m.range(at: 1)
                    return ns.substring(with: r)
                }
            }
        } catch {
            return nil
        }
        return nil
    }
    
    // 同期版（SwiftUIから呼び出し用）
    func fetchMessages() {
        Task {
            await fetchMessages()
        }
    }
    
    // メッセージを送信
    func sendMessage(to groupId: String, text: String) async throws {
        guard !Config.MessagingAPI.channelToken.isEmpty else {
            throw LineAPIError.missingToken
        }
        
        let url = URL(string: "\(baseURL)/send")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageData: [String: Any] = [
            "group_id": groupId,
            "message": text
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: messageData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 {
            throw LineAPIError.sendFailed(httpResponse.statusCode)
        }
    }
}

enum LineAPIError: Error {
    case missingToken
    case sendFailed(Int)
    case fetchFailed(Int)
    
    var localizedDescription: String {
        switch self {
        case .missingToken:
            return "LINE Channel Tokenが設定されていません"
        case .sendFailed(let code):
            return "メッセージ送信に失敗しました (HTTP \(code))"
        case .fetchFailed(let code):
            return "メッセージ取得に失敗しました (HTTP \(code))"
        }
    }
}

// (No extension needed — LineMessageService already implements the MessageRepository requirements)

