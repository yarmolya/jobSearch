import SwiftUI

struct JobDetailsView: View {
    let job: JobBody

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(job.title)
                    .font(.largeTitle)
                    .bold()

                Text("Organisation: \(job.company)".localized())
                    .font(.headline)

                Text("Location: \(job.location)".localized())
                Text("Salary: \(job.salary)".localized())

                Divider()

                Text("Description".localized())
                    .font(.title3)
                    .bold()

                Text(job.description)
                    .padding(.top, 4)
            }
            .padding()
        }
        .navigationTitle("Position".localized())
    }
}

