import SwiftUI
import MapKit

#if canImport(MapboxMaps)
import MapboxMaps
#endif

struct AppConfig: Decodable {
    let openaiProxyUrl: String
    let foursquareProxyUrl: String
    let mapboxAccessToken: String
    let foursquareVersion: String
}

final class AppState: ObservableObject {
    @Published var config: AppConfig?
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadConfig() {
        guard let url = URL(string: "https://wayfarer-ten.vercel.app/api/mobile-config") else { return }
        isLoading = true
        errorMessage = nil
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data else {
                    self.errorMessage = "No config data"
                    return
                }
                do {
                    let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
                    self.config = decoded
                } catch {
                    self.errorMessage = "Failed to decode config"
                }
            }
        }.resume()
    }
}

struct ChatMessage: Identifiable, Codable {
    let id = UUID()
    let role: String
    let content: String
}

final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = [
        ChatMessage(role: "assistant", content: "Ask Wayfarer where you want to go.")
    ]
    @Published var input: String = ""
    @Published var isSending = false
    @Published var errorMessage: String?

    func send(using config: AppConfig?) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userMessage = ChatMessage(role: "user", content: trimmed)
        messages.append(userMessage)
        input = ""
        guard let config, let url = URL(string: config.openaiProxyUrl) else {
            errorMessage = "Missing config"
            return
        }

        isSending = true
        errorMessage = nil
        let payload: [String: Any] = [
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        let body = try? JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isSending = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data else {
                    self.errorMessage = "No response"
                    return
                }
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["text"] as? String {
                    self.messages.append(ChatMessage(role: "assistant", content: text))
                } else {
                    self.errorMessage = "Invalid response"
                }
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
            PlanView()
                .tabItem { Label("Plan", systemImage: "sparkles") }
            TripsView()
                .tabItem { Label("Trips", systemImage: "map") }
        }
        .tint(.black)
        .environmentObject(appState)
        .onAppear { appState.loadConfig() }
    }
}

struct HomeView: View {
    @State private var prompt = ""
    @State private var rotatingPlaceholder = ""
    private let placeholders = [
        "Plan a 7-day adventure in Japan on a budget…",
        "Weekend trip to Nashville with my partner…",
        "Best beaches in Southeast Asia for December…"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeroCard(prompt: $prompt, placeholder: rotatingPlaceholder)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                UpcomingTripsSection()
                    .padding(.horizontal, 20)

                ExploreWorldSection()
                    .padding(.horizontal, 20)

                GuidesSection()
                    .padding(.horizontal, 20)

                FooterCTA()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .onAppear {
            rotatingPlaceholder = placeholders.first ?? "Tell Wayfarer where you want to go…"
            var index = 0
            Timer.scheduledTimer(withTimeInterval: 4.5, repeats: true) { _ in
                index = (index + 1) % placeholders.count
                withAnimation(.easeInOut(duration: 0.35)) {
                    rotatingPlaceholder = placeholders[index]
                }
            }
        }
    }
}

struct HeroCard: View {
    @Binding var prompt: String
    let placeholder: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.65), Color.black.opacity(0.2)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .overlay(
                    Image("hero-collage")
                        .resizable()
                        .scaledToFill()
                        .opacity(0.85)
                        .clipped()
                )

            VStack(alignment: .leading, spacing: 14) {
                Text("WAYFARER")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                Text("Where to next?")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                Text("Tell Wayfarer where you want to go — and let AI handle the rest.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                VStack(spacing: 12) {
                    TextField(placeholder, text: $prompt, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.white)
                        .cornerRadius(16)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)

                    Button(action: {}) {
                        Text("Plan My Trip →")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.black)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(20)
        }
        .frame(height: 320)
        .clipped()
    }
}

struct UpcomingTripsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Upcoming Adventures")
                        .font(.title3.bold())
                    Text("Pick up where you left off")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {}) {
                    Text("See all")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    TripCard(title: "Montreal Getaway", subtitle: "May 12–17", badge: "Next week")
                    TripCard(title: "Paris Weekend", subtitle: "Jun 3–8", badge: "In 3 months")
                }
            }
        }
    }
}

struct TripCard: View {
    let title: String
    let subtitle: String
    let badge: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.1))
                .frame(width: 260, height: 190)
                .overlay(
                    Image("trip-card")
                        .resizable()
                        .scaledToFill()
                        .clipped()
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(14)
        }
        .overlay(
            Text(badge)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.black.opacity(0.7))
                .foregroundColor(.white)
                .clipShape(Capsule())
                .padding(12),
            alignment: .topLeading
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ExploreWorldSection: View {
    private let items = ["Bali", "Barcelona", "Kyoto", "Cape Town", "Mexico City", "New York", "Iceland", "Dubai"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore the World")
                .font(.headline)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(items, id: \.self) { city in
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 140)
                            .overlay(
                                Image("destination-")
                                    .resizable()
                                    .scaledToFill()
                                    .clipped()
                            )
                        Text(city)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(10)
                    }
                }
            }
        }
    }
}

struct GuidesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Not sure where to go?")
                .font(.headline)
            Text("Browse curated guides and jump in fast.")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(["Rome", "Lisbon", "Seoul", "Vancouver", "Buenos Aires", "Copenhagen"], id: \.self) { city in
                    ZStack(alignment: .bottomLeading) {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.1))
                            .frame(height: 140)
                        Text(city)
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .padding(10)
                    }
                }
            }
        }
    }
}

struct FooterCTA: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [Color.black, Color.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 12) {
                Text("Your next adventure is one prompt away.")
                    .font(.headline)
                    .foregroundColor(.white)
                Button(action: {}) {
                    Text("Start Planning Free →")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(16)
                }
            }
            .padding(20)
        }
        .frame(height: 140)
    }
}

struct PlanView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var chatVM = ChatViewModel()
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Chat").tag(0)
                Text("Map").tag(1)
                Text("Itinerary").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == 0 {
                ChatPanelView(viewModel: chatVM)
            } else if selectedTab == 1 {
                MapPanelView(token: appState.config?.mapboxAccessToken)
            } else {
                ItineraryPanelView()
            }
        }
    }
}

struct ChatPanelView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            if let error = appState.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.bottom, 8)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { msg in
                            Text(msg.content)
                                .padding(12)
                                .background(msg.role == "user" ? Color.black.opacity(0.1) : Color.gray.opacity(0.15))
                                .cornerRadius(12)
                                .frame(maxWidth: .infinity, alignment: msg.role == "user" ? .trailing : .leading)
                        }
                    }
                    .padding()
                }
            }
            HStack {
                TextField("Describe your trip…", text: $viewModel.input)
                    .textFieldStyle(.roundedBorder)
                Button(viewModel.isSending ? "..." : "Send") {
                    viewModel.send(using: appState.config)
                }
                .disabled(viewModel.isSending)
            }
            .padding()
        }
    }
}

struct MapPanelView: View {
    let token: String?

    var body: some View {
        #if canImport(MapboxMaps)
        if let token, !token.isEmpty {
            MapboxView(accessToken: token)
        } else {
            Text("Missing Mapbox token")
                .foregroundColor(.secondary)
        }
        #else
        Map(coordinateRegion: .constant(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.6762, longitude: 139.6503),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        ))
        .edgesIgnoringSafeArea(.bottom)
        #endif
    }
}

#if canImport(MapboxMaps)
struct MapboxView: UIViewRepresentable {
    let accessToken: String

    func makeUIView(context: Context) -> MapView {
        let options = ResourceOptions(accessToken: accessToken)
        let mapInitOptions = MapInitOptions(resourceOptions: options, styleURI: .streets)
        return MapView(frame: .zero, mapInitOptions: mapInitOptions)
    }

    func updateUIView(_ uiView: MapView, context: Context) {}
}
#endif

struct ItineraryPanelView: View {
    var body: some View {
        List {
            Section("Day 1") {
                Text("Senso-ji Temple")
                Text("Asakusa Food Street")
            }
            Section("Day 2") {
                Text("Arashiyama Bamboo Grove")
                Text("Kinkaku-ji")
            }
        }
    }
}

struct TripsView: View {
    var body: some View {
        VStack {
            Text("Your Trips")
                .font(.title2.bold())
            Text("Coming soon")
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    ContentView()
}
