import SwiftUI
import UserNotifications

// MARK: - Datenmodelle für die Wetter-API
struct WeatherResponse: Codable {
    let current: CurrentWeather
}

struct CurrentWeather: Codable {
    let windGusts10m: Double

    enum CodingKeys: String, CodingKey {
        case windGusts10m = "wind_gusts_10m" // Nutzung von Böen für realistischere Warnungen
    }
}

// MARK: - Hauptansicht
struct ContentView: View {
    @State private var windSpeed: Double? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    // Definition der Warnschwellen (in km/h)
    let yellowThreshold: Double = 30.0
    let redThreshold: Double = 35.0

    var body: some View {
        VStack(spacing: 20) {
            Text("Windwarnung Aachen")
                .font(.title)
                .bold()
            
            if isLoading {
                ProgressView("Lade aktuelle Winddaten...")
            } else if let wind = windSpeed {
                VStack(spacing: 12) {
                    Text("Aktuelle Windböen:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("\(String(format: "%.1f", wind)) km/h")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    
                    // MARK: - Ampel-Logik für die UI
                    if wind >= redThreshold {
                        // ROTE STUFE
                        HStack {
                            Image(systemName: "exclamationmark.octagon.fill")
                            Text("Gefahr: Sehr starker Wind!")
                        }
                        .padding()
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                        
                    } else if wind >= yellowThreshold {
                        // GELBE STUFE
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Achtung: Erhöhte Windgeschwindigkeit.")
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(.orange) // Orange ist auf hellem/dunklem Grund besser lesbar als Gelb
                        .cornerRadius(10)
                        
                    } else {
                        // GRÜNE STUFE
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Alles ruhig. Kein kritischer Wind.")
                        }
                        .padding()
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                    }
                }
            } else if let error = errorMessage {
                Text("Fehler: \(error)")
                    .foregroundColor(.red)
            }
            
            Button(action: fetchWindData) {
                SwiftUI.Label("Jetzt prüfen & aktualisieren", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding(40)
        .frame(width: 400, height: 320)
        .onAppear {
            requestNotificationPermission()
            fetchWindData()
        }
    }

    // MARK: - Berechtigung für Pop-ups anfordern
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .criticalAlert]) { granted, error in
            if granted {
                print("Benachrichtigungen erlaubt.")
            } else if let error = error {
                print("Fehler bei der Berechtigung: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Dynamische Benachrichtigung mit Systemtönen
    func sendWindNotification(speed: Double, level: WarnLevel) {
        let content = UNMutableNotificationContent()
        
        switch level {
        case .yellow:
            content.title = "⚠️ Gelbe Windwarnung"
            content.body = "Erhöhte Windgeschwindigkeiten von \(String(format: "%.1f", speed)) km/h gemessen."
            
            // Nutzt den ganz normalen Standard-Hinweiston von iOS
            content.sound = UNNotificationSound.default
            
        case .red:
            content.title = "🚨 ROTE Windwarnung!"
            content.body = "Kritische Windböen von \(String(format: "%.1f", speed)) km/h! Bitte Vorsicht."
            
            // Nutzt den systemweiten, unüberhörbaren Standard-ALARMTON für kritische Warnungen
            content.sound = UNNotificationSound.defaultCriticalSound(withAudioVolume: 1.0)
        }
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "windWarning_\(level.rawValue)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error { print("Fehler: \(error.localizedDescription)") }
        }
    }

    // Hilfs-Enum (bleibt gleich)
    enum WarnLevel: String {
        case yellow
        case red
    }

    // MARK: - Wetterdaten abrufen
    func fetchWindData() {
        isLoading = true
        errorMessage = nil
        
        // Open-Meteo API URL für Aachen (umgestellt auf wind_gusts_10m)
        guard let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=50.7817&longitude=6.0474&current=wind_gusts_10m&wind_speed_unit=kmh") else {
            self.errorMessage = "Ungültige URL"
            self.isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "Keine Daten empfangen"
                    return
                }
                
                do {
                    let decodedData = try JSONDecoder().decode(WeatherResponse.self, from: data)
                    let currentWind = decodedData.current.windGusts10m
                    self.windSpeed = currentWind
                    
                    // MARK: - Logik für Benachrichtigung
                    if currentWind >= redThreshold {
                        // Hier .red eintragen, um die rote Warnstufe zu triggern
                        sendWindNotification(speed: currentWind, level: .red)
                    } else if currentWind >= yellowThreshold {
                        // Und hier .yellow für die gelbe Warnstufe
                        sendWindNotification(speed: currentWind, level: .yellow)
                    }
                    
                } catch {
                    self.errorMessage = "Daten konnten nicht gelesen werden."
                }
            }
        }.resume()
    }
}

// MARK: - Vorschau
#Preview {
    ContentView()
}
