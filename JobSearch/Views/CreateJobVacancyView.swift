import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct CreateJobVacancyView: View {
    
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
    
    let vacancyId: String? 
    @ObservedObject var languageManager = LanguageManager.shared
    @Environment(\.dismiss) private var dismiss
    
    
    @State private var jobTitle = ""
    @State private var jobDescription = ""
    @State private var salaryRange = ""
    @State private var jobType = 0 // 0: office, 1: remote, 2: hybrid
    @State private var vacancyDeadline = Date().addingTimeInterval(30*24*60*60) // +30 days
    
   
    @State private var requiredEducationLevel: EducationLevel = .none
    @State private var requiredExperienceType = 0
    @State private var requiredExperienceMonths = 0
    @State private var requiredExperienceYears = 0
    @State private var requiredWorkExperience = 0.0
    @State private var requiresDriverLicense = false
    
  
    @State private var country = ""
    @State private var city = ""
    @State private var cityCoordinates: CLLocationCoordinate2D? = nil
    @State private var cityPlaceId: String = ""
    @State private var countryPlaceId: String = ""
    
   
    @StateObject private var jobFieldVM = JobFieldViewModel()
    @State private var selectedCategory: JobCategory?
    @State private var selectedField: JobCategory.Field?
    
   
    @StateObject private var studyFieldVM = StudyFieldViewModel()
    @State private var selectedStudyCategory: StudyCategory?
    @State private var selectedStudyField: StudyCategory.Field?
    
    @State private var requiredLanguages: [UserLanguage] = []
    @State private var showAddLanguageSheet = false
    
    
    @State private var showTopsisSection = false
    @State private var educationWeight = 0.5
    @State private var experienceWeight = 0.5
    @State private var fieldMatchWeight = 0.5
    @State private var skillsWeight = 0.5
    @State private var locationWeight = 0.3
    
    
    @State private var isSaving = false
    @State private var isLoading = false
    @State private var showSuccessAlert = false
    @State private var errorMessage = ""
    @State private var showErrorAlert = false
    
    
    @StateObject private var countryVM = CountrySearchViewModel()
    @StateObject private var cityVM = CitySearchViewModel()
    
    @Namespace private var scrollTop
    @Namespace private var scrollBottom
    
    let distanceOptions = [0, 5, 15, 30]
    let jobTypes = ["Office", "Remote", "Hybrid"]
    
    var isUkrainian: Bool {
        languageManager.selectedLanguage == "uk"
    }
    
    var isEditing: Bool {
        vacancyId != nil
    }
    
    init(vacancyId: String? = nil) {
        self.vacancyId = vacancyId
    }
    
    var body: some View {
            NavigationStack {
                VStack {
                    ZStack(alignment: .bottom) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("").id(scrollTop)
                                    
                                   
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Job Information".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        TextField("Job Title".localized(), text: $jobTitle)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .padding(.bottom, 8)
                                        
                                        Text("Job Description".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        TextEditor(text: $jobDescription)
                                            .frame(minHeight: 120)
                                            .padding(4)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(8)
                                            .padding(.bottom, 8)
                                        
                                        TextField("Salary Range (e.g. 30,000-40,000 UAH)".localized(), text: $salaryRange)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                            .padding(.bottom, 8)
                                        
                                        Text("Job Type".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Job Type".localized(), selection: $jobType) {
                                            ForEach(0..<jobTypes.count, id: \.self) { index in
                                                Text(jobTypes[index].localized()).tag(index)
                                            }
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        Text("Application Deadline".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        DatePicker("", selection: $vacancyDeadline, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .environment(\.locale, Locale(identifier: LanguageManager.shared.selectedLanguage))

                                        
                                        Text("Job Field".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Job Category", selection: $selectedCategory) {
                                            Text("-").tag(Optional<JobCategory>(nil))
                                            ForEach(jobFieldVM.categories) { category in
                                                Text(isUkrainian ? category.category_uk : category.category_en)
                                                    .tag(Optional(category))
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        if let selectedCategory = selectedCategory {
                                            Text("Job Specialization".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Picker("Specialization".localized(), selection: $selectedField) {
                                                Text("-").tag(Optional<JobCategory.Field>(nil))
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
                                        Text("Requirements".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        Text("Required Education".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Education Level".localized(), selection: $requiredEducationLevel) {
                                            ForEach(EducationLevel.allCases) { level in
                                                Text(level.localized).tag(level)
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        Text("Field of Study".localized())
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        
                                        Picker("Study Category".localized(), selection: $selectedStudyCategory) {
                                            Text("-").tag(Optional<StudyCategory>(nil))
                                            ForEach(studyFieldVM.categories) { category in
                                                Text(isUkrainian ? category.category_uk : category.category_en)
                                                    .tag(Optional(category))
                                            }
                                        }
                                        .pickerStyle(MenuPickerStyle())
                                        .padding(.bottom, 8)
                                        
                                        if let selectedStudyCategory = selectedStudyCategory {
                                            Text("Specialization".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            Picker("Specialization".localized(), selection: $selectedStudyField) {
                                                Text("-").tag(Optional<StudyCategory.Field>(nil))
                                                ForEach(selectedStudyCategory.fields) { field in
                                                    Text(isUkrainian ? field.uk : field.en)
                                                        .tag(Optional(field))
                                                }
                                            }
                                            .pickerStyle(MenuPickerStyle())
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 12) {
                                            Text("Required Languages".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            if requiredLanguages.isEmpty {
                                                Text("No languages added yet".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                    .padding(.vertical, 8)
                                            } else {
                                                ForEach(requiredLanguages) { languageEntry in
                                                    languageListItem(languageEntry)
                                                        .padding(.vertical, 4)
                                                }
                                                .onDelete { indices in
                                                    requiredLanguages.remove(atOffsets: indices)
                                                }
                                            }
                                            
                                            Button(action: {
                                                showAddLanguageSheet = true
                                            }) {
                                                HStack {
                                                    Image(systemName: "plus.circle.fill")
                                                    Text("Add Required Language".localized())
                                                }
                                                .foregroundColor(.blue)
                                                .padding(.vertical, 8)
                                            }
                                        }
                                        .padding(.vertical, 8)
                                        .sheet(isPresented: $showAddLanguageSheet) {
                                            LanguageEntryView(
                                                onSave: { newLanguage in
                                                    requiredLanguages.append(newLanguage)
                                                },
                                                title: "Add Required Language".localized(),
                                                saveButtonTitle: "Add".localized(),
                                                cancelButtonTitle: "Cancel".localized()
                                            )
                                        }
                                        
                                        Picker("Required Experience".localized(), selection: $requiredExperienceType) {
                                            Text("No experience".localized()).tag(0)
                                            Text("Less than a year".localized()).tag(1)
                                            Text("Several years".localized()).tag(2)
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                        .padding(.bottom, 8)
                                        .onChange(of: requiredExperienceType) { _, newValue in
                                            if newValue == 0 {
                                                requiredWorkExperience = 0
                                                requiredExperienceMonths = 0
                                                requiredExperienceYears = 0
                                            }
                                        }
                                        
                                        if requiredExperienceType == 1 {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Months of experience:".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                HStack {
                                                    Button(action: {
                                                        if requiredExperienceMonths > 0 {
                                                            requiredExperienceMonths -= 1
                                                            updateRequiredWorkExperience()
                                                        }
                                                    }) {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundColor(.blue)
                                                    }
                                                    
                                                    Text("\(requiredExperienceMonths)")
                                                        .frame(width: 50)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(Color(.systemGray5))
                                                        .cornerRadius(8)
                                                    
                                                    Button(action: {
                                                        if requiredExperienceMonths < 11 {
                                                            requiredExperienceMonths += 1
                                                            updateRequiredWorkExperience()
                                                        }
                                                    }) {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundColor(.blue)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                            }
                                        } else if requiredExperienceType == 2 {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Years of experience:".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                HStack {
                                                    Button(action: {
                                                        if requiredExperienceYears > 0 {
                                                            requiredExperienceYears -= 1
                                                            updateRequiredWorkExperience()
                                                        }
                                                    }) {
                                                        Image(systemName: "minus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundColor(.blue)
                                                    }
                                                    
                                                    Text("\(requiredExperienceYears)")
                                                        .frame(width: 50)
                                                        .padding(.horizontal, 12)
                                                        .padding(.vertical, 8)
                                                        .background(Color(.systemGray5))
                                                        .cornerRadius(8)
                                                    
                                                    Button(action: {
                                                        requiredExperienceYears += 1
                                                        updateRequiredWorkExperience()
                                                    }) {
                                                        Image(systemName: "plus.circle.fill")
                                                            .font(.title2)
                                                            .foregroundColor(.blue)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                            }
                                        }
                                        
                                        Toggle("Driver's license required".localized(), isOn: $requiresDriverLicense)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Location".localized())
                                            .font(.headline)
                                            .padding(.bottom, 4)
                                        
                                        VStack(alignment: .leading) {
                                            Text("Country".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            TextField("Country".localized(), text: $countryVM.query, onCommit: {
                                                        country = countryVM.query
                                                    })
                                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    .padding(.bottom, 2)
                                            
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
                                                                        countryPlaceId = selectedPrediction.place_id
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
                                            
                                            TextField("City".localized(), text: $cityVM.query, onCommit: {
                                                        city = cityVM.query
                                                    })
                                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                                    .padding(.bottom, 2)
                                            
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
                                                                                cityVM.clearSuggestions()
                                                                                cityCoordinates = coords
                                                                                cityPlaceId = selectedPrediction.place_id
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
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(10)
                                    
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Text("Candidate Selection Priorities".localized())
                                                .font(.headline)
                                                .padding(.bottom, 4)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                withAnimation {
                                                    showTopsisSection.toggle()
                                                }
                                            }) {
                                                Image(systemName: showTopsisSection ? "chevron.up" : "chevron.down")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 16, weight: .semibold))
                                            }
                                        }
                                        
                                        if showTopsisSection {
                                            VStack(alignment: .leading, spacing: 16) {
                                                Text("Set importance for each criteria when selecting candidates.".localized())
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Education:".localized())
                                                            .font(.subheadline)
                                                        Spacer()
                                                        Text(importanceText(for: educationWeight))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Slider(value: $educationWeight, in: 0.0...1.0, step: 0.1)
                                                        .tint(.blue)
                                                }
                                                
                                               
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Experience:".localized())
                                                            .font(.subheadline)
                                                        Spacer()
                                                        Text(importanceText(for: experienceWeight))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Slider(value: $experienceWeight, in: 0.0...1.0, step: 0.1)
                                                        .tint(.blue)
                                                }
                                                
                                             
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Field match:".localized())
                                                            .font(.subheadline)
                                                        Spacer()
                                                        Text(importanceText(for: fieldMatchWeight))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Slider(value: $fieldMatchWeight, in: 0.0...1.0, step: 0.1)
                                                        .tint(.blue)
                                                }
                                                
                                                
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Skills:".localized())
                                                            .font(.subheadline)
                                                        Spacer()
                                                        Text(importanceText(for: skillsWeight))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Slider(value: $skillsWeight, in: 0.0...1.0, step: 0.1)
                                                        .tint(.blue)
                                                }
                                                
                                                
                                                VStack(alignment: .leading, spacing: 6) {
                                                    HStack {
                                                        Text("Location:".localized())
                                                            .font(.subheadline)
                                                        Spacer()
                                                        Text(importanceText(for: locationWeight))
                                                            .font(.caption)
                                                            .foregroundColor(.secondary)
                                                    }
                                                    
                                                    Slider(value: $locationWeight, in: 0.0...1.0, step: 0.1)
                                                        .tint(.blue)
                                                }
                                            }
                                        } else {
                                            Text("Set criteria importance for candidate selection. Tap to expand.".localized())
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
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
                            .onChange(of: showTopsisSection) { _, newValue in
                                if newValue {
                                    withAnimation {
                                        proxy.scrollTo(scrollBottom, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                    
                    
                    Button(action: isEditing ? updateVacancy : publishVacancy) {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text(isEditing ? "Save Changes".localized() : "Publish Vacancy".localized())
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isSaving || jobTitle.isEmpty)
                    .padding()
                    .background(
                        Rectangle()
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 5, y: -5)
                    )
                }
                .navigationTitle(isEditing ? "Edit Vacancy".localized() : "Create Job Vacancy".localized())
                .toolbar {
                    if isEditing {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                dismiss()
                            }
                        }
                    }
                }
                .alert("Success".localized(), isPresented: $showSuccessAlert) {
                    Button("OK", role: .cancel) {
                        dismiss()
                    }
                } message: {
                    Text(isEditing ? "Your vacancy has been updated successfully".localized() : "Your vacancy has been published successfully".localized())
                }
                .alert("Error".localized(), isPresented: $showErrorAlert) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
                .onAppear {
                    jobFieldVM.loadFromJSON()
                    studyFieldVM.loadFromJSON()
                    
                    if let vacancyId = vacancyId {
                        loadVacancyDetails(vacancyId: vacancyId)
                    }
                }
            }
        }
    
    private func loadVacancyDetails(vacancyId: String) {
        isLoading = true
        let db = Firestore.firestore()
        
        db.collection("vacancies").document(vacancyId).getDocument { document, error in
            isLoading = false
            
            if let error = error {
                errorMessage = "Failed to load vacancy: \(error.localizedDescription)"
                showErrorAlert = true
                return
            }
            
            guard let document = document, document.exists else {
                errorMessage = "Vacancy not found"
                showErrorAlert = true
                return
            }
            
            let data = document.data() ?? [:]
            
            jobTitle = data["jobTitle"] as? String ?? ""
            jobDescription = data["jobDescription"] as? String ?? ""
            salaryRange = data["salaryRange"] as? String ?? ""
            
            if let jobTypeString = data["jobType"] as? String {
                if let index = jobTypes.firstIndex(of: jobTypeString) {
                    jobType = index
                }
            }
            
            if let timestamp = data["deadlineDate"] as? Timestamp {
                vacancyDeadline = timestamp.dateValue()
            }
            
           
            if let rawLevel = data["requiredEducationLevel"] as? String,
                let parsedLevel = EducationLevel(rawValue: rawLevel) {
                self.requiredEducationLevel = parsedLevel
            } else {
                self.requiredEducationLevel = .none
            }
            requiredWorkExperience = data["requiredWorkExperience"] as? Double ?? 0.0
            requiresDriverLicense = data["requiresDriverLicense"] as? Bool ?? false
            
      
            if requiredWorkExperience < 1 {
                requiredExperienceType = 1
                requiredExperienceMonths = Int(requiredWorkExperience * 12)
            } else if requiredWorkExperience >= 1 {
                requiredExperienceType = 2
                requiredExperienceYears = Int(requiredWorkExperience)
            }
            
            
            country = data["country"] as? String ?? ""
            city = data["city"] as? String ?? ""
            cityPlaceId = data["city_place_id"] as? String ?? ""
            countryPlaceId = data["country_place_id"] as? String ?? ""
            
            countryVM.query = country
            cityVM.query = city
            
            if let latitude = data["city_latitude"] as? Double,
               let longitude = data["city_longitude"] as? Double {
                cityCoordinates = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            }
            
        
            let jobField = data["jobField"] as? String ?? ""
            let jobSpecialization = data["jobSpecialization"] as? String ?? ""
            
 
            selectedCategory = jobFieldVM.categories.first { category in
                category.category_en == jobField
            }
            
          
            if selectedCategory == nil {
                selectedCategory = jobFieldVM.categories.first { category in
                    category.category_uk == jobField
                }
            }
            
            if let category = selectedCategory {
               
                selectedField = category.fields.first { field in
                    field.en == jobSpecialization
                }
                
           
                if selectedField == nil {
                    selectedField = category.fields.first { field in
                        field.uk == jobSpecialization
                    }
                }
            }
            
           
            let studyField = data["educationField"] as? String ?? ""
            let studySpecialization = data["educationSpecialization"] as? String ?? ""
            
            
            selectedStudyCategory = studyFieldVM.categories.first { category in
                category.category_en == studyField
            }
            
           
            if selectedStudyCategory == nil {
                selectedStudyCategory = studyFieldVM.categories.first { category in
                    category.category_uk == studyField
                }
            }
            
            if let category = selectedStudyCategory {
                
                selectedStudyField = category.fields.first { field in
                    field.en == studySpecialization
                }
                
                
                if selectedStudyField == nil {
                    selectedStudyField = category.fields.first { field in
                        field.uk == studySpecialization
                    }
                }
            }
            
          
            if let languagesData = data["requiredLanguages"] as? [[String: Any]] {
                requiredLanguages = languagesData.compactMap { languageData in
                    guard let id = languageData["id"] as? String,
                          let languageDict = languageData["language"] as? [String: String],
                          let proficiencyRaw = languageData["proficiency"] as? String,
                          let proficiency = ProficiencyLevel(rawValue: proficiencyRaw) else {
                        return nil
                    }
                    
                    let language = Language(en: languageDict["en"] ?? "", uk: languageDict["uk"] ?? "")
                    return UserLanguage(id: id, language: language, proficiency: proficiency)
                }
            }
            
           
            if let weights = data["topsisWeights"] as? [String: Double] {
                educationWeight = weights["educationWeight"] ?? 0.5
                experienceWeight = weights["experienceWeight"] ?? 0.5
                fieldMatchWeight = weights["fieldMatchWeight"] ?? 0.5
                skillsWeight = weights["skillsWeight"] ?? 0.5
                locationWeight = weights["locationWeight"] ?? 0.3
            }
        }
    }
    
    private func updateVacancy() {
        guard let vacancyId = vacancyId else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in".localized()
            showErrorAlert = true
            return
        }
        
        if jobTitle.isEmpty {
            errorMessage = "Job title cannot be empty".localized()
            showErrorAlert = true
            return
        }
        
        isSaving = true
        
        
        let topsisWeights = normalizeWeights()
        
        let db = Firestore.firestore()
        
      
        db.collection("employers").document(uid).getDocument { (document, error) in
            if let error = error {
                isSaving = false
                errorMessage = "Failed to fetch employer data: \(error.localizedDescription)"
                showErrorAlert = true
                return
            }
            
            guard let document = document, document.exists,
                  let companyName = document.data()?["companyName"] as? String else {
                isSaving = false
                errorMessage = "Employer data not found".localized()
                showErrorAlert = true
                return
            }
            
            
            let requiredLanguagesData = requiredLanguages.map { userLanguage -> [String: Any] in
                return [
                    "id": userLanguage.id,
                    "language": [
                        "en": userLanguage.language.en,
                        "uk": userLanguage.language.uk
                    ],
                    "proficiency": userLanguage.proficiency.rawValue
                ]
            }
            
          
            var vacancyData: [String: Any] = [
                
                "jobTitle": jobTitle,
                "jobDescription": jobDescription,
                "salaryRange": salaryRange,
                "jobType": jobTypes[jobType],
                "deadlineDate": Timestamp(date: vacancyDeadline),
                
                
                "requiredEducationLevel": requiredEducationLevel.rawValue,
                "requiredWorkExperience": requiredWorkExperience,
                "requiresDriverLicense": requiresDriverLicense,
                
                
                "requiredLanguages": requiredLanguagesData,
                
             
                "educationField": selectedStudyCategory?.category_en ?? "",
                "educationSpecialization": selectedStudyField?.en ?? "",
                
                
                "jobField": selectedCategory?.category_en ?? "",
                "jobSpecialization": selectedField?.en ?? "",
                
               
                "country": country,
                "city": city,
                "city_latitude": cityCoordinates?.latitude ?? 0.0,
                "city_longitude": cityCoordinates?.longitude ?? 0.0,
                "country_place_id": countryPlaceId,
                "city_place_id": cityPlaceId,
                
               
                "topsisWeights": topsisWeights,
                
                
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
         
            db.collection("vacancies").document(vacancyId).updateData(vacancyData) { error in
                isSaving = false
                
                if let error = error {
                    errorMessage = "Failed to update vacancy: \(error.localizedDescription)"
                    showErrorAlert = true
                } else {
                    showSuccessAlert = true
                }
            }
        }
    }
    
   
    private func importanceText(for weight: Double) -> String {
        switch weight {
        case 0.0:
            return "Not important".localized()
        case 0.1...0.3:
            return "Less important".localized()
        case 0.4...0.6:
            return "Moderately important".localized()
        case 0.7...0.9:
            return "Very important".localized()
        case 1.0:
            return "Essential".localized()
        default:
            return "Moderately important".localized()
        }
    }
    
    private func updateRequiredWorkExperience() {
        if requiredExperienceType == 1 {
            requiredWorkExperience = Double(requiredExperienceMonths) / 12.0
        } else if requiredExperienceType == 2 {
            requiredWorkExperience = Double(requiredExperienceYears)
        }
    }
    
    func languageListItem(_ languageEntry: UserLanguage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(isUkrainian ? languageEntry.language.uk : languageEntry.language.en)
                    .font(.headline)
                Spacer()
                
                Button(action: {
                    if let index = requiredLanguages.firstIndex(where: { $0.id == languageEntry.id }) {
                        requiredLanguages.remove(at: index)
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
    }
    
   
    private func normalizeWeights() -> [String: Double] {
        let totalWeight = educationWeight + experienceWeight + fieldMatchWeight + skillsWeight + locationWeight
        
        
        let factor = totalWeight > 0 ? 1.0 / totalWeight : 1.0
        
        return [
            "educationWeight": educationWeight * factor,
            "experienceWeight": experienceWeight * factor,
            "fieldMatchWeight": fieldMatchWeight * factor,
            "skillsWeight": skillsWeight * factor,
            "locationWeight": locationWeight * factor
        ]
    }
    
    func publishVacancy() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in".localized()
            showErrorAlert = true
            return
        }
        
        if jobTitle.isEmpty {
            errorMessage = "Job title cannot be empty".localized()
            showErrorAlert = true
            return
        }
        
        isSaving = true
        
        
        let topsisWeights = normalizeWeights()
        
        let db = Firestore.firestore()
        
        
        db.collection("employers").document(uid).getDocument { (document, error) in
            if let error = error {
                isSaving = false
                errorMessage = "Failed to fetch employer data: \(error.localizedDescription)"
                showErrorAlert = true
                return
            }
            
            guard let document = document, document.exists,
                  let companyName = document.data()?["companyName"] as? String else {
                isSaving = false
                errorMessage = "Employer data not found".localized()
                showErrorAlert = true
                return
            }
            
          
            let requiredLanguagesData = requiredLanguages.map { userLanguage -> [String: Any] in
                return [
                    "id": userLanguage.id,
                    "language": [
                        "en": userLanguage.language.en,
                        "uk": userLanguage.language.uk
                    ],
                    "proficiency": userLanguage.proficiency.rawValue
                ]
            }
            
           
            var vacancyData: [String: Any] = [
               
                "employerId": uid,
                "companyName": companyName,
                "createdAt": FieldValue.serverTimestamp(),
                "status": "active",
                
               
                "jobTitle": jobTitle,
                "jobDescription": jobDescription,
                "salaryRange": salaryRange,
                "jobType": jobTypes[jobType],
                "deadlineDate": Timestamp(date: vacancyDeadline),
                
                
                "requiredEducationLevel": requiredEducationLevel.rawValue,
                "requiredWorkExperience": requiredWorkExperience,
                "requiresDriverLicense": requiresDriverLicense,
                
               
                "requiredLanguages": requiredLanguagesData,
                
                
                "educationField": selectedStudyCategory?.category_en ?? "",
                "educationSpecialization": selectedStudyField?.en ?? "",
                
               
                "jobField": selectedCategory?.category_en ?? "",
                "jobSpecialization": selectedField?.en ?? "",
                
               
                "country": country,
                "city": city,
                "city_latitude": cityCoordinates?.latitude ?? 0.0,
                "city_longitude": cityCoordinates?.longitude ?? 0.0,
                "country_place_id": countryPlaceId,
                "city_place_id": cityPlaceId,
                
               
                "topsisWeights": topsisWeights,
                
             
                "applicants": [],
                "shortlistedApplicants": []
            ]
            
            
            db.collection("vacancies").addDocument(data: vacancyData) { error in
                isSaving = false
                
                if let error = error {
                    errorMessage = "Failed to publish vacancy: \(error.localizedDescription)"
                    showErrorAlert = true
                } else {
                    showSuccessAlert = true
                }
            }
        }
    }
}


extension CreateJobVacancyView {
    static func forEditing(vacancyId: String) -> CreateJobVacancyView {
        CreateJobVacancyView(vacancyId: vacancyId)
    }
    
    static func forCreation() -> CreateJobVacancyView {
        CreateJobVacancyView()
    }
}
