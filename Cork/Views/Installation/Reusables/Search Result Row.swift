//
//  Search Result Row.swift
//  Cork
//
//  Created by David Bureš on 12.02.2023.
//

import SwiftUI

struct SearchResultRow: View, Sendable
{
    @AppStorage("showDescriptionsInSearchResults") var showDescriptionsInSearchResults: Bool = false
    @AppStorage("showCompatibilityWarning") var showCompatibilityWarning: Bool = true

    @EnvironmentObject var brewData: BrewDataStorage

    let searchedForPackage: BrewPackage
    
    @State private var description: String = ""
    @State private var isCompatible: Bool?

    @State private var isLoadingDescription: Bool = true
    @State private var descriptionParsingFailed: Bool = false

    var body: some View
    {
        VStack(alignment: .leading)
        {
            HStack(alignment: .center)
            {
                SanitizedPackageName(packageName: searchedForPackage.name, shouldShowVersion: true)

                if searchedForPackage.type == .formula
                {
                    if brewData.installedFormulae.contains(where: { $0.name == searchedForPackage.name })
                    {
                        PillTextWithLocalizableText(localizedText: "add-package.result.already-installed")
                    }
                }
                else
                {
                    if brewData.installedCasks.contains(where: { $0.name == searchedForPackage.name })
                    {
                        PillTextWithLocalizableText(localizedText: "add-package.result.already-installed")
                    }
                }

                if let isCompatible
                {
                    if !isCompatible
                    {
                        if showCompatibilityWarning
                        {
                            HStack(alignment: .center, spacing: 4) {
                                Image(systemName: "exclamationmark.circle")
                                Text("add-package.result.not-optimized-for-\(AppConstants.osVersionString.fullName)")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                        }
                    }
                }
            }
            
            if showDescriptionsInSearchResults
            {
                if !descriptionParsingFailed
                { // Show this if the description got properly parsed
                    if isLoadingDescription
                    {
                        Text("add-package.result.loading-description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    else
                    {
                        if !description.isEmpty
                        {
                            Text(description)
                                .font(.caption)
                        }
                        else
                        {
                            Text("add-package.result.description-empty")
                                .font(.caption)
                                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        }
                    }
                }
                else
                { // Otherwise, tell the user the parsing failed
                    Text("add-package.result.loading-failed")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
        }
        .task
        {
            if showDescriptionsInSearchResults
            {
                AppConstants.logger.info("\(searchedForPackage.name, privacy: .auto) came into view")

                if description.isEmpty
                {
                    AppConstants.logger.info("\(searchedForPackage.name, privacy: .auto) does not have its description loaded")

                    async let descriptionRaw = await shell(AppConstants.brewExecutablePath, ["info", "--json=v2", searchedForPackage.name]).standardOutput
                    do
                    {
                        let descriptionJSON = try await parseJSON(from: descriptionRaw)

                        isCompatible = try? getPackageCompatibilityFromJSON(json: descriptionJSON, package: .init(name: searchedForPackage.name, type: searchedForPackage.type, installedOn: Date(), versions: [], sizeInBytes: nil))

                        description = getPackageDescriptionFromJSON(json: descriptionJSON, package: .init(name: searchedForPackage.name, type: searchedForPackage.type, installedOn: Date(), versions: [], sizeInBytes: nil))

                        isLoadingDescription = false
                    }
                    catch let descriptionJSONRetrievalError
                    {
                        AppConstants.logger.error("Failed while retrieving description JSON: \(descriptionJSONRetrievalError, privacy: .public)")
                        isLoadingDescription = false
                    }
                }
                else
                {
                    AppConstants.logger.info("\(searchedForPackage.name, privacy: .auto) already has its description loaded")
                }
            }
        }
    }
}
