import SwiftUI
import Firebase
import FirebaseFirestore

class TopsisCalculator {
 
    private var educationWeight: Double = 0.2
    private var experienceWeight: Double = 0.2
    private var fieldMatchWeight: Double = 0.2
    private var languagesWeight: Double = 0.2
    private var locationWeight: Double = 0.2
    
  
    private var idealPositive: [Double] = []
    private var idealNegative: [Double] = []
   
    init(weights: [String: Double]) {
        self.educationWeight = weights["educationWeight"] ?? 0.2
        self.experienceWeight = weights["experienceWeight"] ?? 0.2
        self.fieldMatchWeight = weights["fieldMatchWeight"] ?? 0.2
        self.languagesWeight = weights["skillsWeight"] ?? 0.2 
        self.locationWeight = weights["locationWeight"] ?? 0.2
    }
    
    
    func rankCandidates(
        vacancyData: [String: Any],
        candidates: [[String: Any]]
    ) -> [TopsisCandidate] {
       
        let requiredEducationLevel = educationLevelToNumeric(vacancyData["requiredEducationLevel"] as? String ?? "No education")
        let requiredExperience = vacancyData["requiredWorkExperience"] as? Double ?? 0.0
        let vacancyJobField = vacancyData["jobField"] as? String ?? ""
        let vacancySpecialization = vacancyData["jobSpecialization"] as? String ?? ""
        let vacancyCity = vacancyData["city"] as? String ?? ""
        let vacancyCountry = vacancyData["country"] as? String ?? ""
        let requiresDriverLicense = vacancyData["requiresDriverLicense"] as? Bool ?? false
        let requiredLanguages = vacancyData["requiredLanguages"] as? [[String: Any]] ?? []
        let requiredStudyField = vacancyData["educationField"] as? String ?? ""
        let requiredSpecialization = vacancyData["educationSpecialization"] as? String ?? ""
        
     
        var decisionMatrix: [[Double]] = []
        var originalData: [[String: Any]] = []
        var rawScores: [[Double]] = [] 
        
        
        let weights = [
            educationWeight,
            experienceWeight,
            fieldMatchWeight,
            languagesWeight,
            locationWeight
        ]
        
        
        for candidateData in candidates {
           
            let candidateEducationLevel = educationLevelToNumeric(candidateData["educationLevel"] as? String ?? "No education")
            let candidateStudyField = candidateData["studyField"] as? String ?? ""
            let candidateSpecialization = candidateData["specialization"] as? String ?? ""
            let educationScore = calculateEducationScore(
                requiredLevel: requiredEducationLevel,
                candidateLevel: candidateEducationLevel,
                requiredStudyField: requiredStudyField,
                candidateStudyField: candidateStudyField,
                requiredSpecialization: requiredSpecialization,
                candidateSpecialization: candidateSpecialization
            )
            
            print("====================================")
            print("Candidate: \(candidateData["firstName"] as? String ?? "Unknown") \(candidateData["lastName"] as? String ?? "")")
            
      
            var workExperience: [WorkExperience] = []
            
        
            if let experienceArray = candidateData["workExperiences"] as? [[String: Any]] {
                print("✅ Found workExperiences as array with \(experienceArray.count) entries")
                workExperience = parseWorkExperience(from: experienceArray)
            }
           
            else if let experienceDict = candidateData["workExperiences"] as? [String: [String: Any]] {
                print("✅ Found workExperiences as dictionary with \(experienceDict.count) entries")
                let experienceArray = Array(experienceDict.values)
                workExperience = parseWorkExperience(from: experienceArray)
            }
           
            else if let experienceArray = candidateData["workExperience"] as? [[String: Any]] {
                print("✅ Found workExperience (singular) as array with \(experienceArray.count) entries")
                workExperience = parseWorkExperience(from: experienceArray)
            }
          
            else if let experienceDict = candidateData["workExperience"] as? [String: Any] {
                print("✅ Found workExperience (singular) as dictionary")
                workExperience = parseWorkExperience(from: [experienceDict])
            }
            else {
                print("❌ No recognizable work experience data found")
                print("Available keys:", candidateData.keys)
            }
            
     
            let experienceScore = calculateExperienceScore(
                requiredExperience: requiredExperience,
                requiredField: vacancyJobField,
                requiredSpecialization: vacancySpecialization,
                workExperience: workExperience
            )
            
            var candidateFields: [String] = []
            var candidateSpecializations: [String] = []

         
            if let fieldsArray = candidateData["preferredJobFields"] as? [String] {
                candidateFields = fieldsArray
                print("✅ Found preferredJobFields as flat array: \(fieldsArray)")
                
                if let specializationsArray = candidateData["preferredJobFieldSpecializations"] as? [String] {
                    candidateSpecializations = specializationsArray
                    print("✅ Found preferredJobFieldSpecializations as flat array: \(specializationsArray)")
                }
            }
          
            else if let preferredFieldsArray = candidateData["preferredJobFields"] as? [[String: Any]] {
                print("🔍 Processing preferredJobFields array with \(preferredFieldsArray.count) items")
                
                for fieldGroup in preferredFieldsArray {
                    print("📋 Processing field group: \(fieldGroup)")
                    
                
                    if let category = fieldGroup["category"] as? String {
                        candidateFields.append(category)
                        print("✅ Added category: \(category)")
                    }
                    
                   
                    if let specializationsAny = fieldGroup["preferredJobFieldSpecializations"] {
                        if let specializations = specializationsAny as? [String] {
                            candidateSpecializations.append(contentsOf: specializations)
                            print("✅ Added specializations (direct cast): \(specializations)")
                        } else if let specializationsArray = specializationsAny as? NSArray {
                            let stringArray = specializationsArray.compactMap { $0 as? String }
                            candidateSpecializations.append(contentsOf: stringArray)
                            print("✅ Added specializations (NSArray cast): \(stringArray)")
                        } else {
                            print("❌ Unexpected specializations format: \(type(of: specializationsAny))")
                            print("Value: \(specializationsAny)")
                        }
                    }
                }
            }

            print("🎯 Final extraction results:")
            print("   • Candidate Fields: \(candidateFields)")
            print("   • Candidate Specializations: \(candidateSpecializations)")

            let allFieldsSelected = candidateFields.isEmpty
            let fieldMatchScore = calculateFieldMatchScore(
                vacancyField: vacancyJobField,
                vacancySpecialization: vacancySpecialization,
                candidateFields: candidateFields,
                candidateSpecializations: candidateSpecializations,
                allFieldsSelected: allFieldsSelected
            )
            
           
            let candidateLanguages: [[String: Any]] = {
                guard let languages = candidateData["languages"] as? [[String: Any]] else {
                    return []
                }
                return languages.map { lang in
                    var mapped: [String: Any] = [:]
                    if let language = lang["language"] as? String {
                        mapped["language"] = ["en": language]
                    } else if let languageDict = lang["language"] as? [String: String] {
                        mapped["language"] = languageDict
                    }
                    if let proficiency = lang["proficiency"] as? String {
                        mapped["proficiency"] = proficiency
                    }
                    return mapped
                }
            }()
            
            let languagesScore = calculateLanguagesScore(
                requiredLanguages: requiredLanguages,
                candidateLanguages: candidateLanguages
            )
            
       
            let candidateCity = candidateData["city"] as? String ?? ""
            let candidateCountry = candidateData["country"] as? String ?? ""
            let candidateDistance = candidateData["acceptableDistance"] as? Int ?? 0
            let locationScore = calculateLocationScore(
                vacancyCity: vacancyCity,
                candidateCity: candidateCity,
                vacancyCountry: vacancyCountry,
                candidateCountry: candidateCountry,
                candidateAcceptableDistance: candidateDistance
            )
            
         
            let hasDriverLicense = candidateData["hasDriverLicense"] as? Bool ?? false
            
  
            let scoreRow = [
                educationScore,
                experienceScore,
                fieldMatchScore,
                languagesScore,
                locationScore
            ]
            
  
            print("""
            Candidate: \(candidateData["firstName"] as? String ?? "") \(candidateData["lastName"] as? String ?? "")
            - Education Level: \(candidateData["educationLevel"] as? String ?? "Unknown")
            - Work Experience Fields: \(workExperience.map { "\($0.field) (\($0.specialization))" }.joined(separator: ", "))
            - Work Experience Duration: \(workExperience.reduce(0.0) { $0 + $1.duration }) years
            - Languages: \(candidateLanguages)
            - Preferred Fields: \(candidateFields)
            - Preferred Specializations: \(candidateSpecializations)
            """)
            
            rawScores.append(scoreRow)
            
        
            decisionMatrix.append(scoreRow)
            
    
            originalData.append(candidateData)
            print("""
                scores:
                - Education: \(educationScore)
                - Experience: \(experienceScore)
                - Field Match: \(fieldMatchScore)
                - Languages: \(languagesScore)
                - Location: \(locationScore)
                """)
        }
        

        var topsisScores: [Double] = Array(repeating: 0.0, count: candidates.count)
        
        if candidates.count > 1 {
            
            let normalizedMatrix = normalizeMatrix(decisionMatrix)
            
      
            let weightedMatrix = applyWeights(normalizedMatrix, weights: weights)
     
            calculateIdealSolutions(weightedMatrix)
            
      
            let separations = calculateSeparationMeasures(weightedMatrix)
            
           
            topsisScores = calculateRelativeCloseness(separations)
        }

        var absoluteScores: [Double] = []
        
        for scoreRow in rawScores {
           
            var score = 0.0
            for i in 0..<scoreRow.count {
                score += scoreRow[i] * weights[i]
            }
            
           
            let candidateData = originalData[absoluteScores.count]
            let hasDriverLicense = candidateData["hasDriverLicense"] as? Bool ?? false
            if requiresDriverLicense && !hasDriverLicense {
                score *= 0.5 
            } else if requiresDriverLicense && hasDriverLicense {
                score = min(score * 1.2, 1.0) 
            }
            
            absoluteScores.append(score)
        }
        
      
        var rankedCandidates: [TopsisCandidate] = []
        
        for (index, candidateData) in originalData.enumerated() {
            let id = candidateData["jobSeekerId"] as? String ?? candidateData["uid"] as? String ?? UUID().uuidString
            let firstName = candidateData["firstName"] as? String ?? "Unknown Candidate"
            let lastName = candidateData["lastName"] as? String ?? "Unknown Candidate"
           
            let topsisScore = candidates.count > 1 ? topsisScores[index] : absoluteScores[index]
            let absoluteScore = absoluteScores[index]
            let educationLevel = candidateData["educationLevel"] as? String ?? "Unknown"
            let experience = candidateData["workExperience"] as? Double ?? 0.0
            let city = candidateData["city"] as? String ?? ""
            let country = candidateData["country"] as? String ?? ""
            let location = "\(city) \(country)".trimmingCharacters(in: .whitespacesAndNewlines)
            let hasDriverLicense = candidateData["hasDriverLicense"] as? Bool ?? false
            
         
            let appliedDate: Date
            if let timestamp = candidateData["appliedDate"] as? Timestamp {
                appliedDate = timestamp.dateValue()
            } else if let dateString = candidateData["appliedDate"] as? String {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy 'at' h:mm:ss a Z"
                appliedDate = formatter.date(from: dateString) ?? Date()
            } else {
                appliedDate = Date()
            }
            
           
            var experienceField = ""
            var experienceSpecialization = ""
            if let workExperienceDicts = candidateData["workExperiences"] as? [[String: Any]], let firstExperience = workExperienceDicts.first {
                experienceField = firstExperience["field"] as? String ?? ""
                experienceSpecialization = firstExperience["specialization"] as? String ?? ""
            } else if let workExperienceDicts = candidateData["workExperience"] as? [[String: Any]], let firstExperience = workExperienceDicts.first {
                experienceField = firstExperience["field"] as? String ?? ""
                experienceSpecialization = firstExperience["specialization"] as? String ?? ""
            }
            
     
            var studyField = candidateData["studyField"] as? String ?? ""
            var specialization = candidateData["specialization"] as? String ?? ""
            
            if studyField.isEmpty {
                if let educationData = candidateData["education"] as? [[String: Any]], let firstEducation = educationData.first {
                    studyField = firstEducation["field"] as? String ?? ""
                    specialization = firstEducation["specialization"] as? String ?? ""
                }
            }
            
            rankedCandidates.append(TopsisCandidate(
                id: id,
                firstName: firstName,
                lastName: lastName,
                topsisScore: topsisScore,
                absoluteScore: absoluteScore,
                educationScore: rawScores[index][0],
                experienceScore: rawScores[index][1],
                fieldMatchScore: rawScores[index][2],
                skillsScore: rawScores[index][3],
                locationScore: rawScores[index][4],
                educationLevel: educationLevel,
                experience: experience,
                location: location,
                hasDriverLicense: hasDriverLicense,
                experienceField: experienceField,
                experienceSpecialization: experienceSpecialization,
                studyField: studyField,
                specialization: specialization,
                appliedDate: appliedDate
            ))
        }
        

        rankedCandidates.sort(by: >)
        
        return rankedCandidates
    }
    

    private func educationLevelToNumeric(_ level: String) -> Int {
        let levels = [
            "No education",
            "Secondary",
            "Vocational",
            "Bachelor",
            "Master",
            "Doctoral",
            "Technical"
        ]
        
        return levels.firstIndex(of: level) ?? 0
    }
    
 
    private func calculateEducationScore(
        requiredLevel: Int,
        candidateLevel: Int,
        requiredStudyField: String,
        candidateStudyField: String,
        requiredSpecialization: String,
        candidateSpecialization: String
    ) -> Double {
        print("🎓 Calculating education score:")
        print("• Required level: \(requiredLevel)")
        print("• Candidate level: \(candidateLevel)")
        print("• Required study field: '\(requiredStudyField)'")
        print("• Candidate study field: '\(candidateStudyField)'")
        print("• Required specialization: '\(requiredSpecialization)'")
        print("• Candidate specialization: '\(candidateSpecialization)'")
        
        if requiredLevel == 0 {
            print("✅ No education required. Returning score: 1.0")
            return 1.0
        }
        
        var score: Double
        if candidateLevel >= requiredLevel {
            print("✅ Candidate level meets or exceeds required level.")
            score = 1.0
        } else {
            score = Double(candidateLevel) / Double(requiredLevel)
            print("📉 Candidate level below required. Base score: \(score)")
        }
        
    
        if !requiredStudyField.isEmpty, !candidateStudyField.isEmpty {
            if candidateStudyField.lowercased() != requiredStudyField.lowercased() {
                print("⚠️ Study field mismatch. Applying -0.2 penalty.")
                score -= 0.2
            } else {
                print("✅ Study field matches.")
            }
        }
        
      
        if !requiredSpecialization.isEmpty, !candidateSpecialization.isEmpty {
            if candidateSpecialization.lowercased() != requiredSpecialization.lowercased() {
                print("⚠️ Specialization mismatch. Applying -0.2 penalty.")
                score -= 0.2
            } else {
                print("✅ Specialization matches.")
            }
        }
        
        let finalScore = max(0.0, min(score, 1.0))
        print("🏁 Final education score: \(finalScore)\n")
        return finalScore
    }
    
   
    private func calculateExperienceScore(
        requiredExperience: Double,
        requiredField: String,
        requiredSpecialization: String,
        workExperience: [WorkExperience]
    ) -> Double {
        if requiredExperience == 0 { return 1.0 }
        if workExperience.isEmpty { return 0.0 }
        
        print("🔨 Calculating experience score:")
        print("• Required experience: \(requiredExperience) years")
        print("• Required field: '\(requiredField)'")
        print("• Required specialization: '\(requiredSpecialization)'")
        
        var relevantMonths = 0.0
        
        for exp in workExperience {
            let durationMonths = exp.duration * 12
            
            let expField = exp.field.lowercased()
            let expSpec = exp.specialization.lowercased()
            let reqField = requiredField.lowercased()
            let reqSpec = requiredSpecialization.lowercased()
            
            if expField.isEmpty || reqField.isEmpty {
                continue // Don't count experiences with empty fields
            }
            
            print("• Experience: \(exp.field) (\(exp.specialization)) - \(exp.duration) years")
            
            if expField == reqField {
                if reqSpec.isEmpty || expSpec == reqSpec {
                 
                    print("✅ Perfect field and specialization match - full credit")
                    relevantMonths += durationMonths
                } else {
                  
                    print("⚠️ Field matches but specialization differs - partial credit")
                    relevantMonths += durationMonths * 0.7 // Reduced credit
                }
            } else {
        
                print("❌ No field match - minimal credit")
                relevantMonths += durationMonths * 0.2
            }
        }
        
        let requiredMonths = requiredExperience * 12
        let score = min(relevantMonths / requiredMonths, 1.0)
        print("🏁 Final experience score: \(score)\n")
        return score
    }

    private func calculateFieldMatchScore(
        vacancyField: String,
        vacancySpecialization: String,
        candidateFields: [String],
        candidateSpecializations: [String],
        allFieldsSelected: Bool
    ) -> Double {
        print("=== 📊 Starting Field Match Score Calculation ===")
        print("📌 Inputs:")
        print("• Vacancy Field: '\(vacancyField)'")
        print("• Vacancy Specialization: '\(vacancySpecialization)'")
        print("• Candidate Fields: \(candidateFields)")
        print("• Candidate Specializations: \(candidateSpecializations)")
        print("• All Fields Selected: \(allFieldsSelected)")
        
     
        if vacancyField.isEmpty || allFieldsSelected {
            print("✅ No field specified or all fields selected. Returning score: 0.5")
            return 0.5
        }
        
      
        if candidateFields.isEmpty {
            print("❌ Candidate has no preferred fields. Returning score: 0.0")
            return 0.0
        }
        
        let normalizedVacancyField = vacancyField.lowercased()
        let normalizedVacancySpec = vacancySpecialization.lowercased()
        
        print("\n🔍 Checking for exact matches (field + specialization)...")
        for (i, field) in candidateFields.enumerated() {
            let normalizedField = field.lowercased()
            print("• Comparing candidate field '\(normalizedField)' with vacancy field '\(normalizedVacancyField)'")
            
            if normalizedField == normalizedVacancyField {
                print("✅ Field match!")
                
                if !normalizedVacancySpec.isEmpty {
                    if i < candidateSpecializations.count {
                        let normalizedSpec = candidateSpecializations[i].lowercased()
                        print("• Comparing specialization '\(normalizedSpec)' with vacancy specialization '\(normalizedVacancySpec)'")
                        
                        if normalizedSpec == normalizedVacancySpec {
                            print("✅ Exact field and specialization match found! Returning score: 1.0")
                            return 1.0
                        } else {
                            print("❌ Specializations do not match.")
                        }
                    } else {
                        print("⚠️ No candidate specialization at index \(i).")
                    }
                } else {
                    print("✅ No specialization required. Field match is enough. Returning score: 1.0")
                    return 1.0
                }
            }
        }
        
        print("\n🔍 Checking for partial matches...")
        var bestPartialScore = 0.0
        
        for (i, field) in candidateFields.enumerated() {
            let normalizedField = field.lowercased()
            
            print("• Checking candidate field '\(normalizedField)' for partial match with '\(normalizedVacancyField)'")
            
            if normalizedField.contains(normalizedVacancyField) || normalizedVacancyField.contains(normalizedField) {
                print("⚠️ Partial containment match found.")
                let containmentScore = 0.7
                print("→ Containment score: \(containmentScore)")
                bestPartialScore = max(bestPartialScore, containmentScore)
                continue
            }
            
       
            let vacancyWords = normalizedVacancyField.split(separator: " ")
            let fieldWords = normalizedField.split(separator: " ")
            let commonWords = vacancyWords.filter { fieldWords.contains($0) }
            
            if !commonWords.isEmpty {
                let similarityScore = Double(commonWords.count) / Double(max(vacancyWords.count, fieldWords.count))
                let wordMatchScore = 0.3 + (similarityScore * 0.4)
                print("⚠️ Word-level match found with words: \(commonWords)")
                print("→ Word-level score: \(wordMatchScore)")
                bestPartialScore = max(bestPartialScore, wordMatchScore)
            }
        }
        
 
        if bestPartialScore > 0.0 {
            if !normalizedVacancySpec.isEmpty && !candidateSpecializations.isEmpty {
                let hasMatchingSpec = candidateSpecializations.contains { $0.lowercased() == normalizedVacancySpec }
                if hasMatchingSpec {
                    print("➕ Specialization match bonus applied (+0.1)")
                    bestPartialScore = min(bestPartialScore + 0.1, 1.0)
                } else {
                    print("➖ No specialization match bonus.")
                }
            }
            print("✅ Returning best partial score: \(bestPartialScore)")
            return bestPartialScore
        }
        
        print("❌ No field or specialization match found. Returning fallback score: 0.2")
        return 0.2
    }

    
    
    private func calculateLanguagesScore(
        requiredLanguages: [[String: Any]],
        candidateLanguages: [[String: Any]]
    ) -> Double {
        if requiredLanguages.isEmpty {
            print("🌍 No languages required. Score: 1.0")
            return 1.0
        }
        if candidateLanguages.isEmpty {
            print("🌍 No languages provided. Score: 0.0")
            return 0.0
        }
        
        print("🌍 Required languages: \(requiredLanguages)")
        print("🌍 Candidate languages: \(candidateLanguages)")
        
        var totalScore = 0.0
        let requiredLanguageCount = requiredLanguages.count
        
        
        let proficiencyLevels = ["A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6, "Mother Tongue": 7]
        
 
        for reqLang in requiredLanguages {
           
            var reqLangName = ""
            if let langDict = reqLang["language"] as? [String: String] {
                reqLangName = langDict["en"]?.lowercased() ?? ""
            } else if let langString = reqLang["language"] as? String {
                reqLangName = langString.lowercased()
            }
            
            let reqProficiencyStr = reqLang["proficiency"] as? String ?? "A1"
            let reqProficiency = proficiencyLevels[reqProficiencyStr] ?? 1
            
            print("🔍 Checking for required language: \(reqLangName) at level \(reqProficiencyStr) (numeric: \(reqProficiency))")
            
          
            var bestMatchScore = 0.0
            
            for candLang in candidateLanguages {
              
                var candLangName = ""
                if let langDict = candLang["language"] as? [String: String] {
                    candLangName = langDict["en"]?.lowercased() ?? ""
                } else if let langString = candLang["language"] as? String {
                    candLangName = langString.lowercased()
                }
                
                guard let candProficiencyStr = candLang["proficiency"] as? String,
                      let candProficiency = proficiencyLevels[candProficiencyStr] else {
                    continue
                }
                
                print("🌐 Comparing with candidate language: \(candLangName) at level \(candProficiencyStr) (numeric: \(candProficiency))")
                
                
                if candLangName.lowercased() == reqLangName.lowercased() {
                    print("✅ Match found! Required level: \(reqProficiency), candidate level: \(candProficiency)")
                    
                    let matchScore: Double
                    if candProficiency >= reqProficiency {
                        matchScore = 1.0
                        print("🎯 Candidate meets or exceeds required level - full points")
                    } else {
                      
                        matchScore = Double(candProficiency) / Double(reqProficiency)
                        print("⚠️ Partial credit: \(matchScore)")
                    }
                    
                    bestMatchScore = max(bestMatchScore, matchScore)
                }
            }
            
            totalScore += bestMatchScore
            print("📊 Best match score for required language \(reqLangName): \(bestMatchScore)")
        }
        
     
        let finalScore = totalScore / Double(requiredLanguageCount)
        print("🏁 Final language score: \(finalScore)\n")
        return finalScore
    }
    
 
    private func calculateLocationScore(
        vacancyCity: String,
        candidateCity: String,
        vacancyCountry: String,
        candidateCountry: String,
        candidateAcceptableDistance: Int
    ) -> Double {
      
        if vacancyCity.isEmpty || candidateCity.isEmpty {
            print("📍 No location restrictions. Score: 1.0")
            return 1.0
        }
        
        print("📍 Comparing locations:")
        print("• Vacancy: \(vacancyCity), \(vacancyCountry)")
        print("• Candidate: \(candidateCity), \(candidateCountry)")
        print("• Candidate acceptable distance: \(candidateAcceptableDistance) km")
        

        if vacancyCity.lowercased() == candidateCity.lowercased() {
            print("✅ Cities match exactly. Score: 1.0")
            return 1.0
        }
        
      
        if vacancyCity.lowercased().contains(candidateCity.lowercased()) ||
            candidateCity.lowercased().contains(vacancyCity.lowercased()) {
            print("⚠️ Cities partially match. Score: 0.9")
            return 0.9
        }
        
      
        if !vacancyCountry.isEmpty && !candidateCountry.isEmpty && vacancyCountry.lowercased() != candidateCountry.lowercased() {
            print("❌ Different countries. Score: 0.2")
            return 0.2
        }
        
     
        if vacancyCountry.lowercased() == candidateCountry.lowercased() {
            print("⚠️ Same country, different cities. Score: 0.8")
            return 0.8
        }
        
 
        print("❓ Default location score: 0.5")
        return 0.5
    }
    

    private func normalizeMatrix(_ matrix: [[Double]]) -> [[Double]] {
        guard !matrix.isEmpty else { return [] }
        
        let columnCount = matrix[0].count
        var normalizedMatrix = Array(repeating: Array(repeating: 0.0, count: columnCount), count: matrix.count)
        
       
        var columnSumOfSquares = Array(repeating: 0.0, count: columnCount)
        
        for row in matrix {
            for (j, value) in row.enumerated() {
                columnSumOfSquares[j] += value * value
            }
        }
        
      
        for j in 0..<columnCount {
            columnSumOfSquares[j] = sqrt(columnSumOfSquares[j])
        }
        
  
        for i in 0..<matrix.count {
            for j in 0..<columnCount {
                if columnSumOfSquares[j] > 0 {
                    normalizedMatrix[i][j] = matrix[i][j] / columnSumOfSquares[j]
                } else {
                    normalizedMatrix[i][j] = 0
                }
            }
        }
        
        return normalizedMatrix
    }
    
   
    private func applyWeights(_ matrix: [[Double]], weights: [Double]) -> [[Double]] {
        var weightedMatrix = matrix
        
        for i in 0..<matrix.count {
            for j in 0..<matrix[i].count {
                weightedMatrix[i][j] = matrix[i][j] * weights[j]
            }
        }
        
        return weightedMatrix
    }
    

    private func calculateIdealSolutions(_ weightedMatrix: [[Double]]) {
        guard !weightedMatrix.isEmpty else {
            idealPositive = []
            idealNegative = []
            return
        }
        
        let columnCount = weightedMatrix[0].count
        idealPositive = Array(repeating: Double.leastNonzeroMagnitude, count: columnCount)
        idealNegative = Array(repeating: Double.greatestFiniteMagnitude, count: columnCount)
        
        
        for i in 0..<weightedMatrix.count {
            for j in 0..<columnCount {
                idealPositive[j] = max(idealPositive[j], weightedMatrix[i][j])
                idealNegative[j] = min(idealNegative[j], weightedMatrix[i][j])
            }
        }
    }
    

    private func calculateSeparationMeasures(_ weightedMatrix: [[Double]]) -> [(positive: Double, negative: Double)] {
        var separations: [(positive: Double, negative: Double)] = []
        
        for row in weightedMatrix {
            var positiveDistance: Double = 0
            var negativeDistance: Double = 0
            
            for j in 0..<row.count {
                positiveDistance += pow(row[j] - idealPositive[j], 2)
                negativeDistance += pow(row[j] - idealNegative[j], 2)
            }
            
            separations.append((
                positive: sqrt(positiveDistance),
                negative: sqrt(negativeDistance)
            ))
        }
        
        return separations
    }
    

    private func calculateRelativeCloseness(_ separations: [(positive: Double, negative: Double)]) -> [Double] {
        var scores: [Double] = []
        
        for separation in separations {
            let denominator = separation.positive + separation.negative
            
            if denominator > 0 {
                scores.append(separation.negative / denominator)
            } else {
                scores.append(0)
            }
        }
        
        return scores
    }
    
}
