import SwiftUI
import Firebase
import FirebaseFirestore

struct TopsisRankingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TopsisRankingViewModel()
    
    let vacancyId: String
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding()
                    
                    Text("Ranking candidates...".localized())
                        .font(.headline)
                        .padding()
                } else if viewModel.candidates.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No candidates found".localized())
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        Text("There are no applicants for this vacancy yet".localized())
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(viewModel.candidates, id: \.id) { candidate in
                            let index = viewModel.candidates.firstIndex(where: { $0.id == candidate.id }) ?? 0
                            
                            HStack(spacing: 15) {
                                Text("\(index + 1)")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(rankColor(index: index))
                                    .clipShape(Circle())
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(candidate.firstName) \(candidate.lastName)")
                                        .font(.headline)
                                    
                                    HStack(spacing: 10) {
                                        Label("\(candidate.educationLevel)".localized(), systemImage: "graduationcap")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                        
                                        if candidate.experience > 0 {
                                            Label(formatExperience(candidate.experience), systemImage: "briefcase")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Text(candidate.location)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack {
                                    Text(String(format: "%.0f%%", candidate.absoluteScore * 100))
                                        .font(.headline)
                                        .foregroundColor(scoreColor(score: candidate.absoluteScore))
                                    
                                    Text("match".localized())
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedCandidate = candidate
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Candidate Ranking".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done".localized()) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $viewModel.selectedCandidate) { candidate in
                CandidateDetailView(candidate: candidate)
            }
            .onAppear {
                viewModel.loadCandidates(vacancyId: vacancyId)
            }
        }
    }
    
    private func rankColor(index: Int) -> Color {
        switch index {
        case 0: return Color.green
        case 1: return Color.blue
        case 2: return Color.orange
        default: return Color.gray
        }
    }

    private func scoreColor(score: Double) -> Color {
        if score >= 0.8 {
            return .green
        } else if score >= 0.6 {
            return .blue
        } else if score >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private func formatExperience(_ years: Double) -> String {
        if years < 1 {
            let months = Int(years * 12)
            let format = months == 1 ? "%d \("month".localized())" : "%d \("months".localized())"
            return String(format: format, months)
        } else if years == 1 {
            return "1 \("year".localized())"
        } else {
            if years.truncatingRemainder(dividingBy: 1) == 0 {
                return String(format: "%d \("years".localized())", Int(years))
            } else {
                return String(format: "%.1f \("years".localized())", years)
            }
        }
    }
}

