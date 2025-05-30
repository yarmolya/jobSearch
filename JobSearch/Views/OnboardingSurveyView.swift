import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreLocation


struct OnboardingSurveyView: View {
    enum EducationLevel: String, CaseIterable, Identifiable {
        case none = "No education"
        case secondary = "Secondary"
        case vocational = "Vocational"
        case bachelor = "Bachelor"
        case master = "Master"
        case doctoral = "Doctoral"
        case technical = "Technical"
        
        var id: String { self.rawValue }
        
        var localized: String {
            switch self {
            case .none: return "No education".localized()
            case .secondary: return "Secondary".localized()
            case .vocational: return "Vocational".localized()
            case .bachelor: return "Bachelor".localized()
            case .master: return "Master".localized()
            case .doctoral: return "Doctoral".localized()
            case .technical: return "Technical".localized()
            }
        }
    }
    
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var authStateListener: AuthStateDidChangeListenerHandle?
    
    // Existing state variables
    @State private var educationLevel: EducationLevel = .none
    @State private var hasDriverLicense = false
    @State private var desiredSpecialty = ""
    @State private var country = ""
    @State private var city = ""
    @State private var cityCoordinates: CLLocationCoordinate2D? = nil
    @State private var selectedDistance = 0
    @State private var isSaving = false
    @State private var navigateToHome = false
    @State private var isLoading = true
    
    @State private var cityPlaceId: String = ""
    @State private var countryPlaceId: String = ""
    
    // Work experience variables
    @State private var experienceType = 0 // 0 = none, 1 = has experience
    @State private var workExperiences: [WorkExperience] = []
    @State private var showAddExperienceSheet = false
    @State private var editingExperience: WorkExperience? = nil
    
    //Languages
    @State private var userLanguages: [UserLanguage] = []
    @State private var showAddLanguageSheet = false
    
    // Other existing state variables
    @StateObject private var countryVM = CountrySearchViewModel()
    @StateObject private var cityVM = CitySearchViewModel()
    @StateObject private var studyFieldVM = StudyFieldViewModel()
    @StateObject private var jobFieldVM = JobFieldViewModel()
    
    @State private var selectedStudyCategory: StudyCategory?
    @State private var selectedStudyField: StudyCategory.Field?
    
    // Updated job field selection approach
    @State private var selectedJobCategories: [SelectedJobCategory] = []
    @State private var showingCategoryPicker = false
    @State private var allFieldsSelected = true
    
    // For adding new job category selections
    @State private var currentlyEditingCategoryIndex: Int? = nil
    @State private var showingFieldSelectionSheet = false
    @State private var selectedCategoryForAdding: JobCategory? = nil
    
    @Namespace private var scrollTop
    @Namespace private var scrollBottom
    
    
    
    let distanceOptions = [0, 5, 15, 30]
    
    // Computed property to calculate total work experience
    var totalWorkExperience: Double {
        return workExperiences.reduce(0) { $0 + $1.duration }
    }
    // Format total experience for display
    var formattedTotalExperience: String {
        let years = Int(totalWorkExperience)
        let months = Int((totalWorkExperience - Double(years)) * 12)
        
        if years > 0 && months > 0 {
            return "\(years) \("years".localized()) \(months) \("months".localized())"
        } else if years > 0 {
            return "\(years) \("years".localized())"
        } else if months > 0 {
            return "\(months) \("months".localized())"
        } else {
            return "No experience".localized()
        }
    }
    
    var isUkrainian: Bool {
        languageManager.selectedLanguage == "uk"
    }
    
    // Get all categories that haven't been selected yet
    var availableCategories: [JobCategory] {
        let selectedCategoryIds = Set(selectedJobCategories.map { $0.category.id })
        return jobFieldVM.categories.filter { !selectedCategoryIds.contains($0.id) }
    }
    
    // Count total selected fields across all categories
    var totalSelectedFields: Int {
        selectedJobCategories.reduce(0) { $0 + $1.selectedFields.count }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    loadingView
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("").id(scrollTop)
                                    
                                    // Education Section (unchanged)
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Education".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        Picker("Education Level".localized(), selection: $educationLevel) {
                                            ForEach(EducationLevel.allCases) { level in
                                                Text(level.localized).tag(level)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        Text("Field of study".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Field of Study Category".localized(), selection: $selectedStudyCategory) {
                                            Text("-").tag(Optional<StudyCategory>(nil))
                                            ForEach(studyFieldVM.categories) { category in
                                                Text(isUkrainian ? category.category_uk : category.category_en)
                                                    .tag(Optional(category))
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        if let selectedCategory = selectedStudyCategory {
                                            Text("Specialization".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Picker("Specialization".localized(), selection: $selectedStudyField) {
                                                Text("-").tag(Optional<StudyCategory.Field>(nil))
                                                ForEach(selectedCategory.fields) { field in
                                                    Text(isUkrainian ? field.uk : field.en)
                                                        .tag(Optional(field))
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Languages".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        if userLanguages.isEmpty {
                                            Text("No languages added.".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.vertical, 8)
                                        } else {
                                            ForEach(userLanguages) { languageEntry in
                                                languageListItem(languageEntry)
                                                    .padding(.vertical, 4)
                                            }
                                        }
                                        
                                        Button(action: {
                                            showAddLanguageSheet = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus.circle.fill")
                                                Text("Add language".localized())
                                            }
                                            .foregroundColor(.blue)
                                            .padding(.vertical, 8)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(10)
                                    }
                                    .sheet(isPresented: $showAddLanguageSheet) {
                                        LanguageEntryView { newLanguage in
                                            userLanguages.append(newLanguage)
                                        }
                                    }
                                    
                                    // Work Experience Section (unchanged)
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Work Experience".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        Picker("Work Experience".localized(), selection: $experienceType) {
                                            Text("No experience".localized()).tag(0)
                                            Text("Has experience".localized()).tag(1)
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .padding(.bottom, 8)
                                        .onChange(of: experienceType) { _, newValue in
                                            if newValue == 0 {
                                                workExperiences = []
                                            }
                                        }
                                        
                                        if experienceType == 1 {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Total experience: ".localized() + formattedTotalExperience)
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Spacer()
                                                }
                                                .padding(.bottom, 4)
                                                
                                                // List of work experiences
                                                if workExperiences.isEmpty {
                                                    Text("No work history added.".localized())
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                        .padding(.vertical, 8)
                                                } else {
                                                    ForEach(workExperiences) { experience in
                                                        workExperienceListItem(experience)
                                                            .padding(.vertical, 4)
                                                    }
                                                }
                                                
                                                // Add experience button
                                                Button(action: {
                                                    editingExperience = nil
                                                    showAddExperienceSheet = true
                                                }) {
                                                    HStack {
                                                        Image(systemName: "plus.circle.fill")
                                                        Text("Add work experience".localized())
                                                    }
                                                    .foregroundColor(.blue)
                                                    .padding(.vertical, 8)
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    // UPDATED: Preferred Job Fields Section with hierarchical selection
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Preferred Job Fields".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        Toggle("All fields".localized(), isOn: Binding(
                                            get: { allFieldsSelected },
                                            set: { newValue in
                                                allFieldsSelected = newValue
                                                if newValue {
                                                    selectedJobCategories.removeAll()
                                                    print("🔄 All fields selected, cleared selections")
                                                }
                                            }
                                        ))
                                        
                                        if !allFieldsSelected {
                                            // Display selected categories and their fields
                                            if selectedJobCategories.isEmpty {
                                                Text("No job fields selected".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .padding(.vertical, 8)
                                            } else {
                                                Text("Selected categories:".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                                
                                                ForEach(Array(selectedJobCategories.enumerated()), id: \.element.id) { index, categorySelection in
                                                    categorySelectionView(for: categorySelection, at: index)
                                                }
                                            }
                                            
                                            // Add category button
                                            if !availableCategories.isEmpty {
                                                Button(action: {
                                                    showingCategoryPicker = true
                                                }) {
                                                    HStack {
                                                        Image(systemName: "plus.circle.fill")
                                                        Text("Add job category".localized())
                                                    }
                                                    .foregroundColor(.blue)
                                                    .padding(.vertical, 8)
                                                }
                                                .sheet(isPresented: $showingCategoryPicker) {
                                                    categoryPickerSheet()
                                                }
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    .sheet(isPresented: $showingFieldSelectionSheet) {
                                        if let category = selectedCategoryForAdding {
                                            fieldSelectionSheet(for: category)
                                        }
                                    }
                                    
                                    // Location Section (unchanged)
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Location".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Country".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            TextField("Country".localized(), text: $countryVM.query)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .padding(.bottom, 2)
                                                .onAppear {
                                                    // Initialize with existing country value
                                                    countryVM.query = country
                                                }
                                            
                                            if !countryVM.suggestions.isEmpty {
                                                ScrollView(showsIndicators: false) {
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        ForEach(countryVM.suggestions.prefix(3), id: \.self) { suggestion in
                                                            Text(suggestion)
                                                                .padding(.vertical, 8)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .contentShape(Rectangle())
                                                                .onTapGesture {
                                                                    if let selectedPrediction = countryVM.predictions.first(where: { $0.description == suggestion }) {
                                                                        country = suggestion
                                                                        countryVM.query = suggestion
                                                                        countryVM.clearSuggestions()
                                                                        countryPlaceId = selectedPrediction.place_id // Save the place_id
                                                                    }
                                                                }
                                                            
                                                            if suggestion != countryVM.suggestions.prefix(3).last {
                                                                Divider()
                                                            }
                                                        }
                                                    }
                                                }
                                                .frame(height: min(CGFloat(countryVM.suggestions.count * 44), 132))
                                                .background(Color(.systemBackground))
                                                .cornerRadius(8)
                                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                                .padding(.bottom, 10)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("City".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            TextField("City".localized(), text: $cityVM.query)
                                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                                .padding(.bottom, 2)
                                                .onAppear {
                                                    // Initialize with existing city value
                                                    cityVM.query = city
                                                }
                                            
                                            if !cityVM.suggestions.isEmpty {
                                                ScrollView(showsIndicators: false) {
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        ForEach(cityVM.suggestions.prefix(3), id: \.self) { suggestion in
                                                            Text(suggestion)
                                                                .padding(.vertical, 8)
                                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                                .contentShape(Rectangle())
                                                                .onTapGesture {
                                                                    if let selectedPrediction = cityVM.predictions.first(where: { $0.description == suggestion }) {
                                                                        cityVM.fetchCoordinates(for: selectedPrediction.place_id) { coords in
                                                                            DispatchQueue.main.async {
                                                                                city = suggestion
                                                                                cityVM.query = suggestion
                                                                                cityVM.predictions = []
                                                                                cityCoordinates = coords
                                                                                cityPlaceId = selectedPrediction.place_id // Save the place_id
                                                                            }
                                                                        }
                                                                    }
                                                                }
                                                            
                                                            if suggestion != cityVM.suggestions.prefix(3).last {
                                                                Divider()
                                                            }
                                                        }
                                                    }
                                                }
                                                .frame(height: min(CGFloat(cityVM.suggestions.count * 44), 132))
                                                .background(Color(.systemBackground))
                                                .cornerRadius(8)
                                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                                .padding(.bottom, 10)
                                            }
                                        }
                                        
                                        VStack(alignment: .leading) {
                                            Text("Distance".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Picker("Acceptable Distance from City".localized(), selection: $selectedDistance) {
                                                ForEach(distanceOptions, id: \.self) { distance in
                                                    Text("+\(distance) km").tag(distance)
                                                }
                                            }
                                            .pickerStyle(SegmentedPickerStyle())
                                            .padding(.bottom, 8)
                                        }
                                        
                                        Toggle("I have a driver's license".localized(), isOn: $hasDriverLicense)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    Spacer().frame(height: 1)
                                    Text("").id(scrollBottom)
                                }
                                .padding()
                            }
                            .ignoresSafeArea(.keyboard, edges: .bottom)
                            .scrollDismissesKeyboard(.interactively)
                        }
                    }
                    
                    // Done Button
                    Button(action: saveSurvey) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("done".localized()).bold().frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSaving)
                    .padding()
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 5, y: -5)
                    )
                }
            }
            .navigationTitle("Job Survey".localized())
            .navigationDestination(isPresented: $navigateToHome) {
                JobSeekerHomeView()
            }
            .sheet(isPresented: $showAddExperienceSheet) {
                if let experience = editingExperience {
                    WorkExperienceEntryView(experience: experience) { updatedExperience in
                        if let index = workExperiences.firstIndex(where: { $0.id == updatedExperience.id }) {
                            workExperiences[index] = updatedExperience
                        }
                    }
                } else {
                    WorkExperienceEntryView { newExperience in
                        workExperiences.append(newExperience)
                    }
                }
            }
            .onAppear {
                studyFieldVM.loadFromJSON()
                jobFieldVM.loadFromJSON()
                
                // Add auth state listener with proper handling
                authStateListener = Auth.auth().addStateDidChangeListener { auth, user in
                    if user == nil {
                        print("⚠️ User authentication lost - navigating to login")
                        DispatchQueue.main.async {
                            // Navigate back to login or handle auth loss
                            self.dismiss()
                        }
                    }
                }
                
                fetchUserData()
            }
            .onDisappear {
                // Clean up auth listener
                if let listener = authStateListener {
                    Auth.auth().removeStateDidChangeListener(listener)
                }
            }
            
        }
    }
    
    // View for displaying a selected category and its fields
    func categorySelectionView(for categorySelection: SelectedJobCategory, at index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(isUkrainian ? categorySelection.category.category_uk : categorySelection.category.category_en)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                
                Button(action: {
                    currentlyEditingCategoryIndex = index
                    selectedCategoryForAdding = categorySelection.category
                    showingFieldSelectionSheet = true
                }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    // Remove this category
                    selectedJobCategories.remove(at: index)
                }) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
            }
            
            if categorySelection.selectedFields.isEmpty {
                Text("All fields in this category".localized())
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            } else {
                // Display selected fields for this category
                FlowLayout(spacing: 4) {
                    ForEach(Array(categorySelection.selectedFields), id: \.id) { field in
                        Text(isUkrainian ? field.uk : field.en)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray5).opacity(0.5))
        .cornerRadius(8)
    }
    
    // Sheet for picking a category to add
    func categoryPickerSheet() -> some View {
        NavigationStack {
            List {
                ForEach(availableCategories) { category in
                    Button(action: {
                        selectedCategoryForAdding = category
                        showingCategoryPicker = false
                        showingFieldSelectionSheet = true
                    }) {
                        Text(isUkrainian ? category.category_uk : category.category_en)
                    }
                }
            }
            .navigationTitle("Select Category".localized())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel".localized()) {
                        showingCategoryPicker = false
                    }
                }
            }
        }
    }
    
    func getCurrentUserUID() -> String? {
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user found")
            return nil
        }
        
        let uid = currentUser.uid
        
        guard !uid.isEmpty else {
            print("❌ UID is empty")
            return nil
        }
        
        return uid
    }
    
    // Sheet for selecting fields within a category
    func fieldSelectionSheet(for category: JobCategory) -> some View {
        let isEditing = currentlyEditingCategoryIndex != nil
        
        // Find existing selection if editing
        let existingSelection: Set<JobCategory.Field> = isEditing ?
        selectedJobCategories[currentlyEditingCategoryIndex!].selectedFields : []
        
        return NavigationStack {
            VStack {
                List {
                    // "Select All" option
                    Button(action: {
                        if isEditing {
                            // Clear selections for this category when selecting all
                            selectedJobCategories[currentlyEditingCategoryIndex!].selectedFields = []
                        }
                        // Close sheet when done
                        showingFieldSelectionSheet = false
                        if !isEditing {
                            // Add new category with all fields
                            selectedJobCategories.append(SelectedJobCategory(category: category))
                        }
                        currentlyEditingCategoryIndex = nil
                    }) {
                        HStack {
                            Text("All fields in this category".localized())
                            Spacer()
                            if isEditing && existingSelection.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    // Individual fields
                    ForEach(category.fields) { field in
                        Button(action: {
                            if isEditing {
                                // Toggle this field in the existing category
                                if selectedJobCategories[currentlyEditingCategoryIndex!].selectedFields.contains(field) {
                                    selectedJobCategories[currentlyEditingCategoryIndex!].selectedFields.remove(field)
                                } else {
                                    selectedJobCategories[currentlyEditingCategoryIndex!].selectedFields.insert(field)
                                }
                            } else {
                                // Add new category with just this field selected
                                let newSelection = SelectedJobCategory(
                                    category: category,
                                    selectedFields: [field]
                                )
                                selectedJobCategories.append(newSelection)
                                showingFieldSelectionSheet = false
                            }
                        }) {
                            HStack {
                                Text(isUkrainian ? field.uk : field.en)
                                Spacer()
                                if isEditing && existingSelection.contains(field) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isUkrainian ? category.category_uk : category.category_en)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isEditing {
                        Button("Done".localized()) {
                            showingFieldSelectionSheet = false
                            currentlyEditingCategoryIndex = nil
                        }
                    } else {
                        Button("Cancel".localized()) {
                            showingFieldSelectionSheet = false
                            selectedCategoryForAdding = nil
                        }
                    }
                }
            }
        }
    }
    
    // Custom view for displaying each work experience entry
    func workExperienceListItem(_ experience: WorkExperience) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(experience.position)
                        .font(.headline)
                    Text(experience.company)
                        .font(.subheadline)
                }
                
                Spacer()
                
                Button(action: {
                    editingExperience = experience
                    showAddExperienceSheet = true
                }) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
                
                Button(action: {
                    if let index = workExperiences.firstIndex(where: { $0.id == experience.id }) {
                        workExperiences.remove(at: index)
                    }
                }) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
            }
            
            Text(formatDateRange(start: experience.startDate, end: experience.endDate, isCurrent: experience.isCurrentJob))
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !experience.field.isEmpty {
                Text(experience.field + (experience.specialization.isEmpty ? "" : " - " + experience.specialization))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray5).opacity(0.5))
        .cornerRadius(8)
    }
    
    func languageListItem(_ languageEntry: UserLanguage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(languageEntry.displayName)  // Use displayName here
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    if let index = userLanguages.firstIndex(where: { $0.id == languageEntry.id }) {
                        userLanguages.remove(at: index)
                    }
                }) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
            }
            
            Text(languageEntry.proficiency.localizedString)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(.systemGray5).opacity(0.5))
        .cornerRadius(8)
        .id(LanguageManager.shared.selectedLanguage)  // Force view refresh on language change
    }
    
    // Helper function to format date range
    func formatDateRange(start: Date, end: Date?, isCurrent: Bool) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM yyyy"
        
        let startString = dateFormatter.string(from: start)
        if isCurrent {
            return "\(startString) - \("Present".localized())"
        } else if let end = end {
            let endString = dateFormatter.string(from: end)
            return "\(startString) - \(endString)"
        } else {
            return startString
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading your preferences...".localized())
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    func fetchUserData() {
        // Store UID at the beginning to ensure it's not null during the operation
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user found")
            isLoading = false
            return
        }
        
        let uid = currentUser.uid
        
        guard !uid.isEmpty else {
            print("❌ UID is empty")
            isLoading = false
            return
        }
        
        print("✅ Fetching data for UID: \(uid)")
        
        
        // Keep a local copy of the UID to use throughout this method
        let userID = uid
        
        let db = Firestore.firestore()
        
        db.collection("job_seekers").document(userID).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error fetching profile: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            if let data = snapshot?.data() {
                // Load existing values with dispatch to main thread for UI updates
                DispatchQueue.main.async {
                    // Load education level
                    if let rawLevel = data["educationLevel"] as? String,
                       let parsedLevel = EducationLevel(rawValue: rawLevel) {
                        self.educationLevel = parsedLevel
                    } else {
                        self.educationLevel = .none
                    }
                    self.hasDriverLicense = data["hasDriverLicense"] as? Bool ?? false
                    self.desiredSpecialty = data["desiredSpecialty"] as? String ?? ""
                    self.country = data["country"] as? String ?? ""
                    self.city = data["city"] as? String ?? ""
                    self.cityPlaceId = data["city_place_id"] as? String ?? ""
                    self.countryPlaceId = data["country_place_id"] as? String ?? ""
                    
                    // Set city coordinates if available
                    if let latitude = data["city_latitude"] as? Double,
                       let longitude = data["city_longitude"] as? Double {
                        self.cityCoordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    }
                    
                    // Set the country and city query values
                    self.countryVM.query = self.country
                    self.cityVM.query = self.city
                    
                    // Set acceptable distance
                    self.selectedDistance = data["acceptableDistance"] as? Int ?? 0
                    
                    // Load job fields preference
                    if let jobFieldData = data["preferredJobFields"] {
                        // Check if it's an empty array or structure
                        if let jobFieldArray = jobFieldData as? [Any], jobFieldArray.isEmpty {
                            self.allFieldsSelected = true
                            self.selectedJobCategories = []
                            print("📋 Empty job fields array found, setting allFieldsSelected to true")
                        } else {
                            self.allFieldsSelected = false
                            // Process job fields using the updated function
                            self.processJobFieldsFromDatabase(jobFieldData)
                        }
                    } else {
                        // Default to all fields if not specified
                        self.allFieldsSelected = true
                        self.selectedJobCategories = []
                        print("📋 No job fields key found, defaulting to all fields")
                    }
                    
                    // Find study category and field if available
                    // Note: These are stored in English in the database
                    if let categoryName = data["studyField"] as? String,
                       let specializationName = data["specialization"] as? String {
                        if let category = self.studyFieldVM.categories.first(where: { $0.category_en == categoryName }) {
                            self.selectedStudyCategory = category
                            
                            if let field = category.fields.first(where: { $0.en == specializationName }) {
                                self.selectedStudyField = field
                            }
                        }
                    }
                }
                
                // Fetch and load work experiences and languages
                self.fetchWorkExperiences(uid: userID)
                self.fetchUserLanguages(uid: userID)
            } else {
                print("❌ Profile data not found")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func processJobFieldsFromDatabase(_ jobFieldData: Any) {
        // Clear existing selections
        selectedJobCategories = []
        
        // Handle both old format (array of strings) and new format (array of dictionaries)
        if let fieldNames = jobFieldData as? [String] {
            // OLD FORMAT: Array of field names - convert to new structure
            processLegacyJobFields(fieldNames)
        } else if let structuredData = jobFieldData as? [[String: Any]] {
            // NEW FORMAT: Array of category selections with their fields
            processStructuredJobFields(structuredData)
        }
        
        print("📋 Processed job fields into \(selectedJobCategories.count) categories")
    }

    // Process old format data (array of field names)
    private func processLegacyJobFields(_ fieldNames: [String]) {
        // Create a dictionary to group fields by their category
        var fieldsByCategory: [String: [JobCategory.Field]] = [:]
        
        // Map each field name to its JobCategory.Field object and group by category
        for fieldName in fieldNames {
            // Find the field in all categories by English name
            for category in jobFieldVM.categories {
                if let field = category.fields.first(where: { $0.en == fieldName }) {
                    // If we found the field, add it to the appropriate category group
                    if fieldsByCategory[category.id] == nil {
                        fieldsByCategory[category.id] = [field]
                    } else {
                        fieldsByCategory[category.id]?.append(field)
                    }
                    break // Found the field, no need to check other categories
                }
            }
        }
        
        // Now create SelectedJobCategory objects from the grouped fields
        for (categoryId, fields) in fieldsByCategory {
            if let category = jobFieldVM.categories.first(where: { $0.id == categoryId }) {
                let selectedFields = Set(fields)
                let selection = SelectedJobCategory(category: category, selectedFields: selectedFields)
                selectedJobCategories.append(selection)
            }
        }
    }

    // Process new structured format data
    private func processStructuredJobFields(_ structuredData: [[String: Any]]) {
        for categoryData in structuredData {
            guard let categoryName = categoryData["category"] as? String,
                  let selectedFieldNames = categoryData["selectedFields"] as? [String] else {
                continue
            }
            
            // Find the category by English name
            guard let category = jobFieldVM.categories.first(where: { $0.category_en == categoryName }) else {
                continue
            }
            
            // Convert field names to Field objects
            let selectedFields = Set(selectedFieldNames.compactMap { fieldName in
                category.fields.first(where: { $0.en == fieldName })
            })
            
            // If selectedFields contains all fields in the category, treat as "all fields selected"
            let finalSelectedFields = selectedFields.count == category.fields.count ? Set<JobCategory.Field>() : selectedFields
            
            let selection = SelectedJobCategory(category: category, selectedFields: finalSelectedFields)
            selectedJobCategories.append(selection)
        }
    }
    
    func fetchWorkExperiences(uid: String) {
        let db = Firestore.firestore()
        
        guard !uid.isEmpty else {
            print("❌ Invalid UID provided to fetchWorkExperiences")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        db.collection("job_seekers").document(uid).collection("workExperiences")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching work experiences: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                if let documents = snapshot?.documents {
                    let experiences = documents.compactMap { document -> WorkExperience? in
                        let data = document.data()
                        
                        guard let position = data["position"] as? String,
                              let company = data["company"] as? String,
                              let field = data["field"] as? String,
                              let specialization = data["specialization"] as? String,
                              let startTimestamp = data["startDate"] as? Timestamp,
                              let description = data["description"] as? String,
                              let isCurrentJob = data["isCurrentJob"] as? Bool else {
                            return nil
                        }
                        
                        let id = document.documentID
                        let startDate = startTimestamp.dateValue()
                        var endDate: Date? = nil
                        
                        if !isCurrentJob, let endTimestamp = data["endDate"] as? Timestamp {
                            endDate = endTimestamp.dateValue()
                        }
                        
                        return WorkExperience(
                            id: id,
                            position: position,
                            company: company,
                            field: field,
                            specialization: specialization,
                            startDate: startDate,
                            endDate: endDate,
                            isCurrentJob: isCurrentJob,
                            description: description
                        )
                    }
                    
                    DispatchQueue.main.async {
                        self.workExperiences = experiences
                        
                        if !self.workExperiences.isEmpty {
                            self.experienceType = 1
                        }
                        
                        self.isLoading = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                }
            }
    }
    
    func fetchUserLanguages(uid: String) {
        let db = Firestore.firestore()
        
        guard !uid.isEmpty else {
            print("❌ Invalid UID provided to fetchUserLanguages")
            return
        }
        
        db.collection("job_seekers").document(uid).collection("languages")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error fetching languages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No language documents found.")
                    return
                }
                
                // Load the local JSON file with all language translations
                guard let url = Bundle.main.url(forResource: "Languages", withExtension: "json"),
                      let data = try? Data(contentsOf: url),
                      let allLanguages = try? JSONDecoder().decode([Language].self, from: data) else {
                    print("❌ Failed to load Languages.json")
                    return
                }
                
                let languages = documents.compactMap { document -> UserLanguage? in
                    let data = document.data()
                    
                    guard
                        let languageNameEn = data["language"] as? String,
                        let proficiencyRaw = data["proficiency"] as? String,
                        let proficiency = ProficiencyLevel(rawValue: proficiencyRaw)
                    else {
                        return nil
                    }
                    
                    // Find the full language data from our JSON file
                    guard let fullLanguage = allLanguages.first(where: { $0.en == languageNameEn }) else {
                        return nil
                    }
                    
                    return UserLanguage(
                        id: document.documentID,
                        language: fullLanguage,  // Now includes both en and uk names
                        proficiency: proficiency
                    )
                }
                
                DispatchQueue.main.async {
                    self.userLanguages = languages
                }
            }
    }
    
    
    func saveSurvey() {
        // Store UID at the beginning to ensure it's not null during the operation
        guard let currentUser = Auth.auth().currentUser else {
            print("❌ No authenticated user found")
            isSaving = false
            return
        }
        
        let userID = currentUser.uid
        
        // Double-check UID is not empty
        guard !userID.isEmpty else {
            print("❌ UID is empty")
            isSaving = false
            return
        }
        
        print("✅ Using UID: \(userID)")
        isSaving = true
        
        // Debug output before saving
        print("💾 Saving survey with allFieldsSelected: \(allFieldsSelected)")
        
        // FIXED: Store job field selections as structured data instead of flat array
        let jobFieldSelections: [[String: Any]]
        
        if allFieldsSelected {
            // If all fields are selected, save an empty array
            jobFieldSelections = []
        } else {
            // Store each category selection with its selected fields
            jobFieldSelections = selectedJobCategories.map { categorySelection in
                let categoryData: [String: Any] = [
                    "category": categorySelection.category.category_en, // The main field
                    "categoryId": categorySelection.category.id,
                    "preferredJobFieldSpecializations": categorySelection.selectedFields.isEmpty ?
                    categorySelection.category.fields.map { $0.en } : // All fields in category
                    Array(categorySelection.selectedFields).map { $0.en } // Specific specializations
                ]
                return categoryData
            }
        }
        
        // Debug the data we're about to save
        print("💾 Will save job field selections: \(jobFieldSelections)")
        
        let db = Firestore.firestore()
        
        // Calculate total work experience from workExperiences array
        let totalExperience = workExperiences.reduce(0.0) { $0 + $1.duration }
        
        // Main user data - STORE STRUCTURED JOB FIELD DATA
        let data: [String: Any] = [
            "educationLevel": educationLevel.rawValue,
            "studyField": selectedStudyCategory?.category_en ?? "",
            "specialization": selectedStudyField?.en ?? "",
            // FIXED: Store job field selections as structured data
            "preferredJobFields": jobFieldSelections, // This now contains category + specializations
            "hasDriverLicense": hasDriverLicense,
            "desiredSpecialty": desiredSpecialty,
            "country": countryVM.query.isEmpty ? country : countryVM.query,
            "city": cityVM.query.isEmpty ? city : cityVM.query,
            "city_latitude": cityCoordinates?.latitude ?? 0.0,
            "city_longitude": cityCoordinates?.longitude ?? 0.0,
            "country_place_id": countryPlaceId,
            "city_place_id": cityPlaceId,
            "acceptableDistance": selectedDistance,
            "workExperience": totalExperience,
            "hasWorkHistory": experienceType == 1 && !workExperiences.isEmpty
        ]
        
        // Save main user data
        db.collection("job_seekers").document(userID).setData(data, merge: true) { error in
            if let error = error {
                print("❌ Failed to save survey: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSaving = false
                }
                return
            }
            
            // Save work experiences in a subcollection
            let workExperiencesRef = db.collection("job_seekers").document(userID).collection("workExperiences")
            
            // First, delete all existing work experiences
            workExperiencesRef.getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Failed to fetch existing work experiences: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isSaving = false
                    }
                    return
                }
                
                let dispatchGroup = DispatchGroup()
                
                // Delete existing documents
                if let documents = snapshot?.documents, !documents.isEmpty {
                    for document in documents {
                        dispatchGroup.enter()
                        workExperiencesRef.document(document.documentID).delete { error in
                            if let error = error {
                                print("❌ Failed to delete work experience: \(error.localizedDescription)")
                            }
                            dispatchGroup.leave()
                        }
                    }
                }
                
                // Add new work experiences
                if self.experienceType == 1 {
                    for experience in self.workExperiences {
                        dispatchGroup.enter()
                        
                        var experienceData: [String: Any] = [
                            "position": experience.position,
                            "company": experience.company,
                            "field": experience.field,
                            "specialization": experience.specialization,
                            "startDate": Timestamp(date: experience.startDate),
                            "isCurrentJob": experience.isCurrentJob,
                            "description": experience.description
                        ]
                        
                        if let endDate = experience.endDate {
                            experienceData["endDate"] = Timestamp(date: endDate)
                        }
                        
                        let docRef = workExperiencesRef.document(experience.id)
                        docRef.setData(experienceData) { error in
                            if let error = error {
                                print("❌ Failed to save work experience: \(error.localizedDescription)")
                            }
                            dispatchGroup.leave()
                        }
                    }
                }
                
                // Notify when work experience saving is done
                dispatchGroup.notify(queue: .main) {
                    print("✅ Work experiences saved successfully")
                    
                    // Now save languages
                    let languageDispatchGroup = DispatchGroup()
                    let languagesRef = db.collection("job_seekers").document(userID).collection("languages")
                    
                    languagesRef.getDocuments { snapshot, error in
                        if let error = error {
                            print("❌ Failed to fetch existing languages: \(error.localizedDescription)")
                        } else if let documents = snapshot?.documents {
                            // Delete existing language documents
                            for document in documents {
                                languageDispatchGroup.enter()
                                languagesRef.document(document.documentID).delete { error in
                                    if let error = error {
                                        print("❌ Failed to delete language: \(error.localizedDescription)")
                                    }
                                    languageDispatchGroup.leave()
                                }
                            }
                        }
                        
                        // Add new languages - ALWAYS STORE ENGLISH LANGUAGE NAMES
                        for language in self.userLanguages {
                            languageDispatchGroup.enter()
                            
                            let languageData: [String: Any] = [
                                "language": language.language.en, // ALWAYS use English language name
                                "proficiency": language.proficiency.rawValue // Proficiency levels are already in English
                            ]
                            
                            languagesRef.document(language.id).setData(languageData) { error in
                                if let error = error {
                                    print("❌ Failed to save language: \(error.localizedDescription)")
                                }
                                languageDispatchGroup.leave()
                            }
                        }
                        
                        // When all languages are saved, notify success
                        languageDispatchGroup.notify(queue: .main) {
                            print("✅ Languages saved successfully")
                            // Now that everything is saved, we can update UI state
                            DispatchQueue.main.async {
                                self.isSaving = false
                                self.navigateToHome = true
                            }
                        }
                    }
                }
            }
        }
    }
}


