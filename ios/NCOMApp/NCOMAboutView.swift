import SwiftUI

struct NCOMAboutView: View {
    private let rows: [(String, String)] = [
        ("Name", "NCOM AI"),
        ("Date", "08.26.2026"),
        ("Developer", "NCOM Playground"),
        ("Master Foundation", "NCOM Systems"),
        ("Master Foundation Owner", "Saidie Quinn Newara [ Peter Newara ]"),
        ("Version", "0.1.0"),
        ("Description", "An experiment for making a personal AI."),
        ("Legal", "NOT FOR PUBLIC RELEASE"),
        ("Master Legal Tag", "(c)2025 NCOM Systems PRIVATE PROPERTY"),
        ("Bullet ID", "NCO: Playground08.26.26JENAAIios"),
        ("Contact", "Official_Emmi@outlook.com"),
        ("Apple Store ID", "NOT GIVEN YET"),
        ("Trust Store Version", "2026073000"),
        ("Trust Asset Version", "1013"),
        ("Development Device", "iPhone 17 Pro")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.06)).frame(width: 64, height: 64)
                        Text("ᵔ-ᵔ")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("NCOM AI").font(.title2.bold())
                        Text("Project identity & provenance").foregroundStyle(.secondary)
                    }
                }

                NCOMGlassCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            LabeledContent(row.0, value: row.1)
                                .font(.system(.subheadline, design: .rounded))
                                .padding(.vertical, 9)
                            if index < rows.count - 1 { Divider().opacity(0.18) }
                        }
                    }
                }

                Text("NCOM AI is a private-development project. Distribution, signing, and App Store metadata are controlled separately from the application UI.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding()
        }
        .background(NCOMBackground())
        .navigationTitle("About NCOM")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NCOMBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, Color(red: 0.045, green: 0.05, blue: 0.07), Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
