//
// SettingsPageView.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import SwiftUI

extension MainScreen {
    struct SettingsPageView: View {
        typealias Design = SettingsPageDesign

        @Bindable var viewModel: SettingsPageViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: Design.Layout.spacing) {
                header

                Divider()

                if viewModel.providers.isEmpty {
                    ContentUnavailableView(
                        Design.EmptyState.title,
                        systemImage: Design.EmptyState.icon,
                        description: Text(Design.EmptyState.description)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    HStack(alignment: .top, spacing: Design.Content.columnSpacing) {
                        providerList
                        Divider()
                        providerDetails
                    }
                    .padding(Design.Content.padding)
                }
            }
        }

        private var header: some View {
            VStack(alignment: .leading, spacing: Design.Header.spacing) {
                Text(Design.Header.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(Design.Header.activeProviderPrefix)\(viewModel.activeProviderName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(Design.Header.padding)
        }

        private var providerList: some View {
            VStack(alignment: .leading, spacing: Design.ProviderList.spacing) {
                Text(Design.ProviderList.title)
                    .font(.headline)

                ForEach(viewModel.providers) { provider in
                    Button {
                        viewModel.selectProvider(id: provider.id)
                    } label: {
                        ProviderRow(provider: provider)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: Design.ProviderList.width, alignment: .topLeading)
        }

        @ViewBuilder
        private var providerDetails: some View {
            if let selectedProvider = viewModel.selectedProvider {
                ScrollView {
                    VStack(alignment: .leading, spacing: Design.ProviderDetails.spacing) {
                        VStack(alignment: .leading, spacing: Design.ProviderDetails.titleSpacing) {
                            Text(selectedProvider.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(selectedProvider.id)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        VStack(alignment: .leading, spacing: Design.CapabilityList.spacing) {
                            Text(Design.CapabilityList.title)
                                .font(.headline)

                            ForEach(selectedProvider.capabilities) { capability in
                                CapabilityRow(capability: capability)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private struct ProviderRow: View {
        typealias Design = SettingsPageDesign.ProviderRow

        let provider: ProviderSettingsItem

        var body: some View {
            HStack(spacing: Design.spacing) {
                Image(systemName: provider.isActive ? Design.activeIcon : Design.inactiveIcon)
                    .foregroundStyle(provider.isActive ? .green : .secondary)
                    .frame(width: Design.iconSize, height: Design.iconSize)

                VStack(alignment: .leading, spacing: Design.textSpacing) {
                    Text(provider.name)
                        .font(.body)
                        .fontWeight(provider.isActive ? .semibold : .regular)
                    Text(provider.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(Design.padding)
            .background {
                if provider.isActive {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(.regularMaterial)
                } else {
                    RoundedRectangle(cornerRadius: Design.cornerRadius)
                        .fill(Color.clear)
                }
            }
        }
    }

    private struct CapabilityRow: View {
        typealias Design = SettingsPageDesign.CapabilityRow

        let capability: ProviderCapabilityRow

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: Design.spacing) {
                Text(capability.title)
                    .foregroundStyle(.secondary)
                    .frame(width: Design.titleWidth, alignment: .leading)
                Text(capability.value)
                    .textSelection(.enabled)
                Spacer(minLength: 0)
            }
            .font(.callout)
            .padding(.vertical, Design.verticalPadding)
        }
    }
}
