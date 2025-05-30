import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct WorkExperienceEntryView: View {
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var workExperience: WorkExperience

    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCurrentPosition = false

    @State private var position = ""
    @State private var company = ""
    @State private var description = ""
    @State private var isEditMode: Bool

    @StateObject var jobFieldVM = JobFieldViewModel()
    @State private var selectedCategory: JobCategory?
    @State private var selectedSpecialization: JobCategory.Field?
    @State private var fieldQuery = ""
    @State private var showFieldSearch = false

    @State private var specializationQuery = ""
    @State private var showSpecializationPicker = false

    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var onSave: (WorkExperience) -> Void

    var isUkrainian: Bool {
        languageManager.selectedLanguage == "uk"
    }

    init(onSave: @escaping (WorkExperience) -> Void) {
        _workExperience = State(initialValue: WorkExperience.empty())
        _isEditMode = State(initialValue: false)
        self.onSave = onSave
    }

    init(experience: WorkExperience, onSave: @escaping (WorkExperience) -> Void) {
        _workExperience = State(initialValue: experience)
        _position = State(initialValue: experience.position)
        _company = State(initialValue: experience.company)
        _description = State(initialValue: experience.description)
        _startDate = State(initialValue: experience.startDate)
        _endDate = State(initialValue: experience.endDate ?? Date())
        _isCurrentPosition = State(initialValue: experience.isCurrentJob)
        _isEditMode = State(initialValue: true)
        self.onSave = onSave
    }

    var filteredCategories: [JobCategory] {
        if fieldQuery.isEmpty {
            return jobFieldVM.categories
        } else {
            let searchText = fieldQuery.lowercased()
            return jobFieldVM.categories.filter { category in
                let text = isUkrainian ? category.category_uk.lowercased() : category.category_en.lowercased()
                return text.contains(searchText)
            }
        }
    }

    var filteredSpecializations: [JobCategory.Field] {
        guard let selectedCategory = selectedCategory else { return [] }

        if specializationQuery.isEmpty {
            return selectedCategory.fields
        } else {
            let searchText = specializationQuery.lowercased()
            return selectedCategory.fields.filter { specialization in
                let text = isUkrainian ? specialization.uk.lowercased() : specialization.en.lowercased()
                return text.contains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Job Details".localized())) {
                    TextField("Position".localized(), text: $position)
                    TextField("Company".localized(), text: $company)
                }

                Section(header: Text("Field".localized())) {
                    if let category = selectedCategory {
                        HStack {
                            Text(isUkrainian ? category.category_uk : category.category_en)
                            Spacer()
                            Button(action: {
                                selectedCategory = nil
                                selectedSpecialization = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }

                        if !category.fields.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Specialization".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                if let specialization = selectedSpecialization {
                                    HStack {
                                        Text(isUkrainian ? specialization.uk : specialization.en)
                                        Spacer()
                                        Button(action: {
                                            selectedSpecialization = nil
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                        }
                                    }
                                } else {
                                    Button(action: { showSpecializationPicker = true }) {
                                        HStack {
                                            Text("Select Specialization".localized())
                                                .foregroundColor(.blue)
                                            Spacer()
                                        }
                                    }
                                }

                                if showSpecializationPicker {
                                    TextField("Search specialization...".localized(), text: $specializationQuery)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .padding(.vertical, 4)

                                    if filteredSpecializations.isEmpty {
                                        Text("No results".localized())
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .padding(.top, 4)
                                    } else {
                                        ScrollView(showsIndicators: false) {
                                            VStack(alignment: .leading, spacing: 0) {
                                                ForEach(filteredSpecializations, id: \.self) { specialization in
                                                    Text(isUkrainian ? specialization.uk : specialization.en)
                                                        .padding(.vertical, 8)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .contentShape(Rectangle())
                                                        .onTapGesture {
                                                            selectedSpecialization = specialization
                                                            specializationQuery = ""
                                                            showSpecializationPicker = false
                                                        }

                                                    if specialization != filteredSpecializations.prefix(5).last {
                                                        Divider()
                                                    }
                                                }
                                            }
                                        }
                                        .frame(height: min(CGFloat(filteredSpecializations.count * 44), 150))
                                        .background(Color(.systemBackground))
                                        .cornerRadius(8)
                                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                    }
                                }
                            }
                        }
                    } else {
                        Button(action: { showFieldSearch = true }) {
                            HStack {
                                Text("Select Field".localized())
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }

                        if showFieldSearch {
                            TextField("Search job fields...".localized(), text: $fieldQuery)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.vertical, 4)

                            if filteredCategories.isEmpty {
                                Text("No results".localized())
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 4)
                            } else {
                                ScrollView(showsIndicators: false) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(filteredCategories, id: \.self) { category in
                                            Text(isUkrainian ? category.category_uk : category.category_en)
                                                .padding(.vertical, 8)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedCategory = category
                                                    selectedSpecialization = nil
                                                    fieldQuery = ""
                                                    showFieldSearch = false
                                                }

                                            if category != filteredCategories.prefix(5).last {
                                                Divider()
                                            }
                                        }
                                    }
                                }
                                .frame(height: min(CGFloat(filteredCategories.count * 44), 150))
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                            }
                        }
                    }
                }

                Section(header: Text("Dates".localized())) {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: LanguageManager.shared.selectedLanguage))


                    Toggle("Current Position".localized(), isOn: $isCurrentPosition)

                    if !isCurrentPosition {
                        DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: LanguageManager.shared.selectedLanguage))

                    }
                }

                Section(header: Text("Description".localized())) {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isEditMode ? "Edit Experience".localized() : "Add Experience".localized())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel".localized()) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: saveExperience) {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Done".localized())
                                .bold()
                        }
                    }
                    .disabled(isSaving || position.isEmpty || company.isEmpty || selectedCategory == nil)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error".localized()),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                jobFieldVM.loadFromJSON()
                print("Loaded categories:", jobFieldVM.categories.count)

                if isEditMode {
                    if !workExperience.field.isEmpty {
                        selectedCategory = jobFieldVM.categories.first { category in
                            (isUkrainian ? category.category_uk : category.category_en) == workExperience.field
                        }

                        if let category = selectedCategory {
                            selectedSpecialization = category.fields.first { specialization in
                                (isUkrainian ? specialization.uk : specialization.en) == workExperience.specialization
                            }
                        }
                    }
                }
            }
        }
    }

    func saveExperience() {
        guard !position.isEmpty, !company.isEmpty, let category = selectedCategory else {
            alertMessage = "Please complete all required fields".localized()
            showAlert = true
            return
        }

        let specializationName = selectedSpecialization.map { isUkrainian ? $0.uk : $0.en } ?? ""

        isSaving = true

        let updatedExperience = WorkExperience(
            id: workExperience.id,
            position: position,
            company: company,
            field: category.category_en, // Always save English
            specialization: selectedSpecialization?.en ?? "", // Always save English
            startDate: startDate,
            endDate: isCurrentPosition ? nil : endDate,
            isCurrentJob: isCurrentPosition,
            description: description
        )

        onSave(updatedExperience)
        dismiss()
    }
}

extension WorkExperience {
    static func empty() -> WorkExperience {
        return WorkExperience(
            position: "",
            company: "",
            field: "",
            specialization: "",
            startDate: Date(),
            endDate: nil,
            isCurrentJob: false,
            description: ""
        )
    }
}
