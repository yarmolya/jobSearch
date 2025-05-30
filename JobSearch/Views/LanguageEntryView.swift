import SwiftUI

struct LanguageEntryView: View {
    @StateObject var languageVM = LanguageViewModel()
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var languageManager = LanguageManager.shared

    @State private var selectedLanguageIndex: Int = 0
    @State private var selectedProficiency: ProficiencyLevel = .b1

    var onSave: ((UserLanguage) -> Void)?
    
    var title: String = "Add Language".localized()
    var saveButtonTitle: String = "Save".localized()
    var cancelButtonTitle: String = "Cancel".localized()

    var isUkrainian: Bool {
        languageManager.selectedLanguage == "uk"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Select Language".localized())) {
                    if !languageVM.languages.isEmpty {
                        Picker("Language".localized(), selection: $selectedLanguageIndex) {
                            ForEach(0..<languageVM.languages.count, id: \.self) { index in
                                Text(isUkrainian ? languageVM.languages[index].uk : languageVM.languages[index].en)
                                    .tag(index)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    } else {
                        Text("No languages available.".localized())
                    }
                }

                Section(header: Text("Proficiency Level".localized())) {
                    Picker("Level".localized(), selection: $selectedProficiency) {
                        ForEach(ProficiencyLevel.allCases) { level in
                            Text(level.localizedString).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(cancelButtonTitle) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        let language = languageVM.languages[selectedLanguageIndex]
                        let userLanguage = UserLanguage(
                            language: language,
                            proficiency: selectedProficiency
                        )
                        onSave?(userLanguage)
                        dismiss()
                    }
                    .disabled(languageVM.languages.isEmpty)
                }
            }
            .onAppear {
                languageVM.loadFromJSON()
            }
        }
    }
}
